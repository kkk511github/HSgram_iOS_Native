import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct HSCameraCaptureResult {
    let data: Data
    let fileName: String
    let mimeType: String
    let mediaKind: String
}

struct HSCameraCaptureView: UIViewControllerRepresentable {
    let onComplete: (HSCameraCaptureResult?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.videoQuality = .typeMedium

        let supportedTypes = UIImagePickerController.availableMediaTypes(for: .camera) ?? []
        let desiredTypes = [UTType.image.identifier, UTType.movie.identifier]
        let mediaTypes = desiredTypes.filter { supportedTypes.contains($0) }
        if !mediaTypes.isEmpty {
            picker.mediaTypes = mediaTypes
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onComplete: (HSCameraCaptureResult?) -> Void

        init(onComplete: @escaping (HSCameraCaptureResult?) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onComplete(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let mediaType = info[.mediaType] as? String, mediaType == UTType.movie.identifier,
               let url = info[.mediaURL] as? URL {
                do {
                    let data = try Data(contentsOf: url)
                    onComplete(HSCameraCaptureResult(
                        data: data,
                        fileName: "hsgram-camera-\(Int(Date().timeIntervalSince1970)).mov",
                        mimeType: "video/quicktime",
                        mediaKind: "video"
                    ))
                } catch {
                    onComplete(nil)
                }
                return
            }

            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.86) else {
                onComplete(nil)
                return
            }
            onComplete(HSCameraCaptureResult(
                data: data,
                fileName: "hsgram-camera-\(Int(Date().timeIntervalSince1970)).jpg",
                mimeType: "image/jpeg",
                mediaKind: "photo"
            ))
        }
    }
}
