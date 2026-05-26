import MoteCore
import SwiftUI

struct ModelSettingsView: View {
    @ObservedObject var store: ModelSettingsStore
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var showsAdvancedConfiguration = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            configuration
            message
            footer
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 24)
        .frame(width: 540)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Model Settings")
                .font(.title3.weight(.semibold))

            Text("Choose a provider and model for rewrites.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var configuration: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Provider")
                    .font(.headline)

                Picker("Provider", selection: providerSelection) {
                    ForEach(store.providers) { provider in
                        Text(provider.name).tag(provider.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Model")
                        .font(.headline)

                    Spacer()

                    Button {
                        Task { await store.discoverModels() }
                    } label: {
                        if store.isDiscovering {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Discover", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                    .disabled(store.isDiscovering)

                    if store.canUseFreeModel {
                        Button {
                            Task { await store.selectFreeModel() }
                        } label: {
                            Label("Use Free", systemImage: "sparkles")
                        }
                        .buttonStyle(.plain)
                        .controlSize(.small)
                        .disabled(store.isDiscovering)
                    }
                }

                Picker("Model", selection: $store.selectedModelID) {
                    ForEach(modelOptions, id: \.id) { model in
                        Text(model.displayName).tag(model.id)
                    }
                }
                .labelsHidden()
                .disabled(modelOptions.isEmpty)
                .frame(maxWidth: .infinity, alignment: .leading)

                if modelOptions.isEmpty {
                    Text("Discover models or enter one in Advanced Configuration.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            DisclosureGroup("Advanced Configuration", isExpanded: $showsAdvancedConfiguration) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Base URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("https://example.com/v1", text: $store.baseURL)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        SecureField(apiKeyPlaceholder, text: $store.apiKey)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Model ID")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("model-id", text: $store.selectedModelID)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 10)
            }
            .font(.callout)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()

            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)

            Button("Save") {
                if store.save() {
                    onSave()
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!store.canSave || store.isDiscovering)
        }
    }

    @ViewBuilder
    private var message: some View {
        if let error = store.errorMessage {
            Text(error)
                .font(.callout)
                .foregroundStyle(.red)
                .lineLimit(3)
        } else if let status = store.statusMessage {
            Text(status)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var providerSelection: Binding<String> {
        Binding(
            get: { store.selectedProviderID },
            set: { providerID in
                guard let provider = ModelProvider.find(id: providerID) else { return }
                store.selectProvider(provider)
            }
        )
    }

    private var apiKeyPlaceholder: String {
        store.selectedProvider.apiKeyRequired ? "Required" : "Optional"
    }

    private var modelOptions: [ProviderModel] {
        if store.models.isEmpty, !store.selectedModelID.isEmpty {
            return [ProviderModel(id: store.selectedModelID)]
        }

        return store.models
    }

}
