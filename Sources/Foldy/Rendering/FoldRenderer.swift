#if !os(watchOS)
import MetalKit
import MetalPerformanceShaders

@MainActor
final class FoldRenderer: NSObject, MTKViewDelegate {
    let view: MTKView
    private let queue: any MTLCommandQueue
    private let pipeline: any MTLRenderPipelineState
    private var source: (any MTLTexture)?
    private var destination: (any MTLTexture)?
    private(set) var submittedFrames = 0
    private var pendingUniforms: FoldUniforms?
    private var didSubmit = false
    /// Frames still executing on the GPU. Beyond `maxInFlight` a tick is skipped rather than blocking.
    private var inFlight = 0
    private var needsImmediateFrame = false
    private static let maxInFlight = 2
    /// Poses arrive whenever SwiftUI or a gesture updates; drawing happens once per display refresh.
    private var latest: FoldUniforms?
    private var isDirty = false
    private var link: CADisplayLink?
    /// Sigma of the Gaussian applied to each mip level, in that level's pixels. Combined with the
    /// box downsample this makes level L blur by about 2^L source pixels.
    private static let levelSigma: Float = 1.0

    init(device: (any MTLDevice)? = MTLCreateSystemDefaultDevice()) throws {
        guard let device,
              let queue = device.makeCommandQueue() else { throw FoldFallbackReason.metalUnavailable }
        self.queue = queue
        let library = try device.makeDefaultLibrary(bundle: FoldShaderLibrary.bundle)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "foldVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "foldFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        view = MTKView(frame: .zero, device: device)
        super.init()
        view.delegate = self
        view.colorPixelFormat = .bgra8Unorm
        view.isOpaque = false
        view.backgroundColor = .clear
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        // The drawable is sized explicitly from the capture scale. A host that changes the layer's
        // contents scale, as SwiftUI does under `scaleEffect`, must not multiply it past GPU limits.
        view.autoResizeDrawable = false
        // Drawables join the current Core Animation transaction, so the first frame of a session
        // appears in the same commit that hides the live views and the last one leaves with them.
        view.presentsWithTransaction = true
    }

    /// Uploads both snapshots and builds their blur pyramids once. Every later frame samples one
    /// trilinear tap per pixel instead of a sparse disc.
    func prepare(source: CGImage, destination: CGImage?) throws {
        guard let device = view.device else { throw FoldFallbackReason.metalUnavailable }
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .SRGB: false,
            .origin: MTKTextureLoader.Origin.topLeft,
            .generateMipmaps: true,
            .textureUsage: NSNumber(value: MTLTextureUsage([.shaderRead, .shaderWrite]).rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue)
        ]
        let first = try loader.newTexture(cgImage: source, options: options)
        let second = try destination.map { try loader.newTexture(cgImage: $0, options: options) }
        if let command = queue.makeCommandBuffer() {
            blurPyramid(of: first, device: device, command: command)
            if let second { blurPyramid(of: second, device: device, command: command) }
            command.commit()
        }
        self.source = first
        self.destination = second ?? first
        // The first frame of a session must land before live content is hidden.
        needsImmediateFrame = true
    }

    /// Softens each mip level in place so trilinear sampling approximates a Gaussian of 2^lod pixels.
    /// Zero edges let blurred content fade out at the snapshot boundary instead of ending in a hard cut.
    private func blurPyramid(of texture: any MTLTexture, device: any MTLDevice, command: any MTLCommandBuffer) {
        guard MPSSupportsMTLDevice(device), texture.mipmapLevelCount > 1 else { return }
        let blur = MPSImageGaussianBlur(device: device, sigma: Self.levelSigma)
        blur.edgeMode = .zero
        for level in 1..<texture.mipmapLevelCount {
            guard var levelView = texture.makeTextureView(pixelFormat: texture.pixelFormat, textureType: .type2D,
                                                          levels: level..<(level + 1), slices: 0..<1) else { continue }
            blur.encode(commandBuffer: command, inPlaceTexture: &levelView, fallbackCopyAllocator: Self.copyAllocator)
        }
    }

    private static let copyAllocator: MPSCopyAllocator = { kernel, command, source in
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: source.pixelFormat,
            width: source.width, height: source.height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        return command.device.makeTexture(descriptor: descriptor)!
    }

    /// Draws the first frame of a session now; later poses are drawn on the next display refresh.
    /// Returns false only when an immediate frame could not be submitted.
    @discardableResult
    func draw(_ uniforms: FoldUniforms) -> Bool {
        if needsImmediateFrame {
            needsImmediateFrame = false
            isDirty = false
            latest = uniforms
            startLink()
            return submit(uniforms)
        }
        latest = uniforms
        isDirty = true
        startLink()
        return true
    }

    private func submit(_ uniforms: FoldUniforms) -> Bool {
        pendingUniforms = uniforms
        didSubmit = false
        view.draw()
        pendingUniforms = nil
        return didSubmit
    }

    private func startLink() {
        guard link == nil else { return }
        let target = LinkTarget()
        target.owner = self
        let link = CADisplayLink(target: target, selector: #selector(LinkTarget.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    private func stopLink() {
        link?.invalidate()
        link = nil
    }

    private func tick() {
        guard isDirty, inFlight < Self.maxInFlight, let latest, source != nil else { return }
        isDirty = false
        _ = submit(latest)
    }

    /// Sizes the drawable for a view of `bounds` at `scale` pixels per point.
    func setDrawableSize(bounds: CGSize, scale: CGFloat) {
        view.drawableSize = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard var uniforms = pendingUniforms else { return }
        // A layout pass can leave the view with no size or, under a transform, an absurd one.
        // Requesting a drawable then aborts inside Metal, so skip the frame instead.
        let size = view.drawableSize
        guard size.width >= 1, size.height >= 1, size.width <= 8192, size.height <= 8192 else { return }
        guard let source, let destination,
              let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let command = queue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(source, index: 0)
        encoder.setFragmentTexture(destination, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<FoldUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        command.addCompletedHandler { [weak self] _ in
            Task { @MainActor in self?.frameCompleted() }
        }
        command.commit()
        command.waitUntilScheduled()
        drawable.present()
        inFlight += 1
        submittedFrames += 1
        didSubmit = true
    }

    private func frameCompleted() {
        inFlight = max(inFlight - 1, 0)
    }

    func releaseSnapshots() {
        // Committed command buffers retain the resources they reference until completion.
        stopLink()
        latest = nil
        isDirty = false
        source = nil
        destination = nil
        view.releaseDrawables()
    }

    @MainActor private final class LinkTarget: NSObject {
        weak var owner: FoldRenderer?
        @objc func tick(_ link: CADisplayLink) {
            guard let owner else { link.invalidate(); return }
            owner.tick()
        }
    }
}
#endif
