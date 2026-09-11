import XCTest
import SwiftUI
import Observation
import Foldy

@MainActor @Observable
private final class SharedText {
    var value = "Injected model"
}

private struct EnvironmentProbe: View {
    @Environment(SharedText.self) private var model: SharedText?
    @Environment(\.locale) private var locale
    let report: (String, String) -> Void

    var body: some View {
        Text(model?.value ?? "Missing")
            .onAppear { report(model?.value ?? "Missing", locale.identifier) }
    }
}

final class FoldEnvironmentTests: XCTestCase {
    @MainActor
    func testHostingBoundaryPreservesModelAndLocale() async throws {
        let observed = expectation(description: "Content received the caller's environment")
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let content = FoldTransition(progress: 0) {
            EnvironmentProbe { text, locale in
                XCTAssertEqual(text, "Injected model")
                XCTAssertEqual(locale, "ka_GE")
                observed.fulfill()
            }
        } destination: {
            Text("Destination")
        }
        .environment(SharedText())
        .environment(\.locale, Locale(identifier: "ka_GE"))
        window.rootViewController = UIHostingController(rootView: content)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        await fulfillment(of: [observed], timeout: 3)
    }
}
