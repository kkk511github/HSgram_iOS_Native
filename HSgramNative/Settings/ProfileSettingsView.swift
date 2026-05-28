import PhotosUI
import SwiftUI
import UIKit

struct ProfileSettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var displayName = ""
    @State private var username = ""
    @State private var about = ""
    @State private var email = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoImage: UIImage?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var isUploadingPhoto = false
    @State private var isRemovingPhoto = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }

            Section {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HSProfilePhotoPickerRow(
                        displayName: displayName,
                        image: selectedPhotoImage,
                        isUploading: isUploadingPhoto,
                        isRemoving: isRemovingPhoto
                    )
                }
                .buttonStyle(.plain)
                .disabled(isUploadingPhoto || isRemovingPhoto || authStore.session == nil)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)

                Button("移除当前头像", role: .destructive) {
                    Task {
                        await removePhoto()
                    }
                }
                .disabled(isUploadingPhoto || isRemovingPhoto || authStore.session == nil)
            }

            Section("账号") {
                TextField("显示名称", text: $displayName)
                    .textInputAutocapitalization(.words)
                TextField("用户名", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                LabeledContent("邮箱", value: email)
            }

            Section("简介") {
                TextField("关于", text: $about)
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("个人资料")
        .onChange(of: selectedPhotoItem) { item in
            Task {
                await uploadSelectedPhoto(item)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSaving ? "保存中" : "保存") {
                    Task {
                        await save()
                    }
                }
                .disabled(isSaving || isUploadingPhoto || isRemovingPhoto || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        guard let session = authStore.session, !isLoading else {
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let profile = try await authStore.api.accountProfile(session: session)
            displayName = profile.displayName
            username = profile.username ?? ""
            about = profile.about
            email = profile.email
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            return
        }
        guard let session = authStore.session else {
            selectedPhotoItem = nil
            return
        }

        isUploadingPhoto = true
        errorMessage = nil
        defer {
            isUploadingPhoto = false
            selectedPhotoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpegData = Self.compressedAvatarJPEG(from: image) else {
                errorMessage = "无法读取头像图片。"
                return
            }
            try await authStore.api.uploadProfilePhoto(data: jpegData, session: session)
            selectedPhotoImage = UIImage(data: jpegData) ?? image
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removePhoto() async {
        guard let session = authStore.session else {
            return
        }
        isRemovingPhoto = true
        errorMessage = nil
        defer {
            isRemovingPhoto = false
        }

        do {
            try await authStore.api.removeProfilePhoto(session: session)
            selectedPhotoImage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let session = authStore.session else {
            return
        }
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            errorMessage = "请输入显示名称。"
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let profile = try await authStore.api.updateAccountProfile(
                displayName: normalizedName,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                about: about.trimmingCharacters(in: .whitespacesAndNewlines),
                session: session
            )
            displayName = profile.displayName
            username = profile.username ?? ""
            about = profile.about
            email = profile.email
            authStore.replaceSessionProfile(displayName: profile.displayName, email: profile.email)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func compressedAvatarJPEG(from image: UIImage) -> Data? {
        let maxSide: CGFloat = 1024
        let longestSide = max(image.size.width, image.size.height)
        let scale = longestSide > maxSide ? maxSide / longestSide : 1
        let targetSize = CGSize(
            width: max(1, floor(image.size.width * scale)),
            height: max(1, floor(image.size.height * scale))
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: 0.7)
    }
}

private struct HSProfilePhotoPickerRow: View {
    let displayName: String
    let image: UIImage?
    let isUploading: Bool
    let isRemoving: Bool

    private var isBusy: Bool {
        isUploading || isRemoving
    }

    private var title: String {
        if isRemoving {
            return "正在移除头像"
        }
        if isUploading {
            return "正在上传头像"
        }
        return "更换头像"
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                } else {
                    HSClassicAvatar(title: displayName, icon: "person.fill", tint: HSTheme.accent, size: 96)
                }

                Image(systemName: "camera.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(HSTheme.accent, in: Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))

                if isBusy {
                    ProgressView()
                        .tint(HSTheme.accent)
                        .frame(width: 96, height: 96)
                        .background(.white.opacity(0.72), in: Circle())
                }
            }

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HSTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityLabel(title)
    }
}
