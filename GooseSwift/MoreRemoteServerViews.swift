import Foundation
import SwiftUI
import UIKit

@MainActor
final class MoreRemoteServerViewModel: ObservableObject {
  @Published var serverURL: String
  @Published var bearerToken: String
  @Published var uploadEnabled: Bool
  @Published var urlValidationError: String?
  @Published var saveSuccess: Bool = false

  init() {
    serverURL = UserDefaults.standard.string(forKey: RemoteServerStorage.serverURL) ?? ""
    bearerToken = (try? RemoteServerKeychain.loadToken()) ?? ""
    uploadEnabled = UserDefaults.standard.bool(forKey: RemoteServerStorage.uploadEnabled)
  }

  func save() {
    guard RemoteServerURLValidator.validate(serverURL) else {
      urlValidationError = "URL inválida. Use https://hostname (não IPs numéricos)."
      return
    }
    urlValidationError = nil
    UserDefaults.standard.set(serverURL, forKey: RemoteServerStorage.serverURL)
    UserDefaults.standard.set(uploadEnabled, forKey: RemoteServerStorage.uploadEnabled)
    try? RemoteServerKeychain.saveToken(bearerToken)
    saveSuccess = true
  }
}

struct MoreRemoteServerView: View {
  @StateObject private var vm = MoreRemoteServerViewModel()

  var body: some View {
    Form {
      Section("Server") {
        TextField("https://meu-servidor.local", text: $vm.serverURL)
          .keyboardType(.URL)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
        if let error = vm.urlValidationError {
          Text(error)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }

      Section("Authentication") {
        SecureField("Bearer token (API key)", text: $vm.bearerToken)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
      }

      Section("Upload") {
        Toggle("Enable Upload", isOn: $vm.uploadEnabled)
      }

      Section {
        Button("Save") {
          vm.save()
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white)
      }
    }
    .navigationTitle("Remote Server")
    .navigationBarTitleDisplayMode(.inline)
    .listStyle(.insetGrouped)
    .gooseListBackground()
    .alert("Configurações guardadas", isPresented: $vm.saveSuccess) {
      Button("OK") {}
    }
  }
}
