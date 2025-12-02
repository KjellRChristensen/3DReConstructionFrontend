import SwiftUI
import SceneKit
import QuickLook

struct ModelViewer: View {
    let url: URL
    @State private var scene: SCNScene?
    @State private var error: String?
    @State private var previewURL: URL?

    var body: some View {
        VStack {
            if let scene = scene {
                SceneKitView(scene: scene)
                    .ignoresSafeArea(edges: .bottom)
            } else if let error = error {
                errorView(error)
            } else {
                loadingView
            }
        }
        .navigationTitle(url.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if url.pathExtension.lowercased() == "usdz" {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        previewURL = url
                    } label: {
                        Label("View in AR", systemImage: "arkit")
                    }
                }
            }
        }
        .quickLookPreview($previewURL)
        .task {
            await loadModel()
        }
        .onDisappear {
            // Clear scene to free memory
            scene = nil
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading 3D model...")
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Failed to load model")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func loadModel() async {
        do {
            let loadedScene = try SCNScene(url: url, options: [
                .checkConsistency: true,
                .flattenScene: true
            ])
            await MainActor.run {
                self.scene = loadedScene
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
}

struct SceneKitView: UIViewRepresentable {
    let scene: SCNScene

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = UIColor.systemBackground

        // Reduce memory usage
        scnView.antialiasingMode = .none
        scnView.preferredFramesPerSecond = 30

        // Add lights only once via coordinator
        context.coordinator.setupLighting(for: scene)

        // Frame the scene
        scnView.pointOfView?.camera?.automaticallyAdjustsZRange = true

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Only update if scene changed
        if uiView.scene !== scene {
            uiView.scene = scene
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        private var lightsAdded = false

        func setupLighting(for scene: SCNScene) {
            guard !lightsAdded else { return }
            lightsAdded = true

            // Add ambient light
            let ambientLight = SCNNode()
            ambientLight.light = SCNLight()
            ambientLight.light?.type = .ambient
            ambientLight.light?.intensity = 500
            ambientLight.name = "ambientLight"
            scene.rootNode.addChildNode(ambientLight)

            // Add directional light
            let directionalLight = SCNNode()
            directionalLight.light = SCNLight()
            directionalLight.light?.type = .directional
            directionalLight.light?.intensity = 1000
            directionalLight.position = SCNVector3(x: 5, y: 10, z: 5)
            directionalLight.look(at: SCNVector3Zero)
            directionalLight.name = "directionalLight"
            scene.rootNode.addChildNode(directionalLight)
        }
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        uiView.scene = nil
        uiView.removeFromSuperview()
    }
}

#Preview {
    NavigationStack {
        ModelViewer(url: URL(fileURLWithPath: "/tmp/test.obj"))
    }
}
