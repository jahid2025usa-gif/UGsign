//
//  SigningView.swift
//  Feather
//
//  Created by samara on 14.04.2025.
//

import SwiftUI
import PhotosUI
import NimbleViews
import Zip

// MARK: - View
struct SigningView: View {
	@Environment(\.dismiss) var dismiss
	@StateObject private var _optionsManager = OptionsManager.shared
	
	// UG Sign: compression level is shared with Settings → Archive &
	// Compression (`Feather.compressionLevel` stores the index into
	// `ZipCompression.allCases`, see `ArchiveHandler`).
	@AppStorage("Feather.compressionLevel") private var _compressionLevel: Int = ZipCompression.DefaultCompression.rawValue
	
	@State private var _temporaryOptions: Options = OptionsManager.shared.options
	@State private var _temporaryCertificate: Int
	@State private var _isAltPickerPresenting = false
	@State private var _isFilePickerPresenting = false
	@State private var _isImagePickerPresenting = false
	@State private var _isSigning = false
	@State private var _selectedPhoto: PhotosPickerItem? = nil
	@State var appIcon: UIImage?
	
	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>
	
	private func _selectedCert() -> CertificatePair? {
		guard certificates.indices.contains(_temporaryCertificate) else { return nil }
		return certificates[_temporaryCertificate]
	}
	
	var app: AppInfoPresentable
	
	init(app: AppInfoPresentable) {
		self.app = app
		let storedCert = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		__temporaryCertificate = State(initialValue: storedCert)
	}
		
	// MARK: Body
	var body: some View {
		NBNavigationView("", displayMode: .inline) {
			Form {
				_header(for: app)
				_identity(for: app)
				_certificate()
				_logo(for: app)
				_removeLibrary(for: app)
				_injection(for: app)
				_compression()
				_other()
				_moreOptions()
				
				// horrible
				Rectangle()
					.foregroundStyle(.clear)
					.frame(height: 30)
					.listRowBackground(EmptyView())
			}
			.overlay {
				VStack(spacing: 0) {
					Spacer()
					NBVariableBlurView()
						.frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 60 : 80)
						.rotationEffect(.degrees(180))
						.overlay {
							Button {
								_start()
							} label: {
								NBSheetButton(title: .localized("Signature"), style: .prominent)
									.padding()
							}
							.buttonStyle(.plain)
							.offset(y: UIDevice.current.userInterfaceIdiom == .pad ? -20 : -40)
						}
				}
				.ignoresSafeArea(edges: .bottom)
			}

			.toolbar {
				NBToolbarButton(role: .dismiss)
				ToolbarItem(placement: .principal) {
					Text("UG")
						.font(.system(size: 24, weight: .black, design: .rounded))
						.foregroundStyle(Color(red: 1.0, green: 0.18, blue: 0.33))
				}
				NBToolbarButton(
					.localized("Reset"),
					style: .text,
					placement: .topBarTrailing
				) {
					_temporaryOptions = OptionsManager.shared.options
					appIcon = nil
				}
			}
			.sheet(isPresented: $_isAltPickerPresenting) { SigningAlternativeIconView(app: app, appIcon: $appIcon, isModifing: .constant(true)) }
			.sheet(isPresented: $_isFilePickerPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.image],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self.appIcon = UIImage.fromFile(selectedFileURL)?.resizeToSquare()
					}
				)
				.ignoresSafeArea()
			}
			.photosPicker(isPresented: $_isImagePickerPresenting, selection: $_selectedPhoto)
			.onChange(of: _selectedPhoto) { newValue in
				guard let newValue else { return }
				
				Task {
					if let data = try? await newValue.loadTransferable(type: Data.self),
					   let image = UIImage(data: data)?.resizeToSquare() {
						appIcon = image
					}
				}
			}
			.disabled(_isSigning)
			.animation(.smooth, value: _isSigning)
		}
		.onAppear {
			// ppq protection
			if
				_optionsManager.options.ppqProtection,
				let identifier = app.identifier,
				let cert = _selectedCert(),
				cert.ppQCheck
			{
				_temporaryOptions.appIdentifier = "\(identifier).\(_optionsManager.options.ppqString)"
			}
			
			if
				let currentBundleId = app.identifier,
				let newBundleId = _temporaryOptions.identifiers[currentBundleId]
			{
				_temporaryOptions.appIdentifier = newBundleId
			}
			
			if
				let currentName = app.name,
				let newName = _temporaryOptions.displayNames[currentName]
			{
				_temporaryOptions.appName = newName
			}
		}
	}
}

// MARK: - Extension: View
extension SigningView {
	@ViewBuilder
	private func _header(for app: AppInfoPresentable) -> some View {
		Section {
			VStack(spacing: 10) {
				if let icon = appIcon {
					Image(uiImage: icon)
						.appIconStyle()
				} else {
					FRAppIconView(app: app, size: 88)
				}
				
				Text(app.name ?? .localized("Unknown"))
					.font(.title2.bold())
				
				Text(app.identifier ?? .localized("Unknown"))
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity)
			.listRowBackground(EmptyView())
		}
	}
	
	// MARK: - ESign-style sections
	//
	// ESign lays the signing screen out flat: one section per field, in
	// this order — name, bundle id, clone, version, install, certificate,
	// logo, library, injection, compression, then the "Other" toggles.
	// Only options Feather's Zsign engine actually applies are shown;
	// anything ESign has that Zsign cannot do is left out (see report).
	
	@ViewBuilder
	private func _identity(for app: AppInfoPresentable) -> some View {
		NBSection(.localized("App Name")) {
			_valueCell(_temporaryOptions.appName ?? app.name) {
				SigningPropertiesView(
					title: .localized("App Name"),
					initialValue: _temporaryOptions.appName ?? (app.name ?? ""),
					bindingValue: $_temporaryOptions.appName
				)
			}
		}
		
		NBSection(.localized("Bundle Identifier")) {
			_valueCell(_temporaryOptions.appIdentifier ?? app.identifier) {
				SigningPropertiesView(
					title: .localized("Bundle Identifier"),
					initialValue: _temporaryOptions.appIdentifier ?? (app.identifier ?? ""),
					bindingValue: $_temporaryOptions.appIdentifier
				)
			}
		}
		
		NBSection(.localized("App Clone")) {
			Toggle(.localized("App Clone"), isOn: $_temporaryOptions.appClone)
		} footer: {
			Text(.localized("Installs a second copy of the app next to the original by adding .clone to the bundle id."))
		}
		
		NBSection(.localized("Version")) {
			_valueCell(_temporaryOptions.appVersion ?? app.version) {
				SigningPropertiesView(
					title: .localized("Version"),
					initialValue: _temporaryOptions.appVersion ?? (app.version ?? ""),
					bindingValue: $_temporaryOptions.appVersion
				)
			}
		}
		
		NBSection(.localized("Install after signed")) {
			Toggle(.localized("Install after signed"), isOn: $_temporaryOptions.post_installAppAfterSigned)
		}
	}
	
	@ViewBuilder
	private func _certificate() -> some View {
		NBSection(.localized("Select Certificate")) {
			if let cert = _selectedCert() {
				NavigationLink {
					CertificatesView(selectedCert: $_temporaryCertificate)
				} label: {
					CertificatesCellView(
						cert: cert
					)
				}
			} else {
				Text(.localized("No Certificate"))
					.font(.footnote)
					.foregroundColor(.disabled())
			}
		}
	}
	
	@ViewBuilder
	private func _logo(for app: AppInfoPresentable) -> some View {
		NBSection(.localized("Modify Logo")) {
			HStack {
				Text(.localized("Logo"))
				Spacer()
				Menu {
					Button(.localized("Select Alternative Icon"), systemImage: "app.dashed") { _isAltPickerPresenting = true }
					Button(.localized("Choose from Files"), systemImage: "folder") { _isFilePickerPresenting = true }
					Button(.localized("Choose from Photos"), systemImage: "photo") { _isImagePickerPresenting = true }
				} label: {
					if let icon = appIcon {
						Image(uiImage: icon)
							.appIconStyle()
					} else {
						FRAppIconView(app: app, size: 56)
					}
				}
			}
		}
	}
	
	@ViewBuilder
	private func _removeLibrary(for app: AppInfoPresentable) -> some View {
		NBSection(.localized("Remove existing library")) {
			NavigationLink(.localized("Remove existing library")) {
				SigningDylibView(
					app: app,
					options: $_temporaryOptions.optional()
				)
			}
			
			NavigationLink(.localized("Frameworks & PlugIns")) {
				SigningFrameworksView(
					app: app,
					options: $_temporaryOptions.optional()
				)
			}
		}
	}
	
	@ViewBuilder
	private func _injection(for app: AppInfoPresentable) -> some View {
		NBSection(.localized("Library injection Settings")) {
			HStack {
				Text(.localized("inject path"))
				Picker("", selection: $_temporaryOptions.injectPath) {
					ForEach(Options.InjectPath.allCases, id: \.self) { path in
						Text(path.localizedDescription).tag(path)
					}
				}
				.pickerStyle(.segmented)
				.labelsHidden()
			}
			
			HStack {
				Text(.localized("inject folder"))
				Picker("", selection: $_temporaryOptions.injectFolder) {
					ForEach(Options.InjectFolder.allCases, id: \.self) { folder in
						Text(folder.localizedDescription).tag(folder)
					}
				}
				.pickerStyle(.segmented)
				.labelsHidden()
			}
			
			Text(verbatim: "@executable_path/xxx.dylib")
				.font(.footnote)
				.foregroundStyle(.secondary)
			
			NavigationLink(.localized("Add library  (dylib,framework,deb)")) {
				SigningTweaksView(
					options: $_temporaryOptions
				)
			}
			
			Text(.localized("Add or replace info.plist content"))
				.font(.footnote)
				.foregroundStyle(.secondary)
			
			NavigationLink(.localized("Add Key - Value")) {
				ConfigurationDictView(
					title: .localized("Add Key - Value"),
					dataDict: $_temporaryOptions.customInfoPlist,
					keyLabel: .localized("Key"),
					valueLabel: .localized("Value")
				)
			}
			
			Text(.localized("Custom signature entitlements,It may not be installed after signing."))
				.font(.footnote)
				.foregroundStyle(.secondary)
			
			NavigationLink(.localized("Select entitlements file")) {
				SigningEntitlementsView(
					bindingValue: $_temporaryOptions.appEntitlementsFile
				)
			}
			
			Text(.localized("Package file name"))
				.font(.footnote)
				.foregroundStyle(.secondary)
			
			Text(_packageFileName)
				.font(.footnote)
		} footer: {
			Text(.localized("The number in the package file name is the time the IPA is packed."))
		}
	}
	
	@ViewBuilder
	private func _compression() -> some View {
		NBSection(.localized("Compress Level")) {
			Picker("", selection: $_compressionLevel) {
				Text(.localized("Speed")).tag(_compressionSpeedIndex)
				Text(.localized("Balanced")).tag(_compressionBalancedIndex)
				Text(.localized("Size")).tag(_compressionSizeIndex)
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			
			Text(_compressionDescription)
				.font(.footnote)
				.foregroundStyle(.secondary)
		}
	}
	
	@ViewBuilder
	private func _other() -> some View {
		NBSection(.localized("Other")) {
			Toggle(.localized("Remove all plug-in"), isOn: $_temporaryOptions.removeAllPlugins)
			Toggle(.localized("Remove all watch apps"), isOn: $_temporaryOptions.removeAllWatchApps)
			Toggle(.localized("Set MinimumOSVersion:iOS 10.0"), isOn: _minimumOSVersionBinding)
			Toggle(.localized("Remove UISupportedDevices"), isOn: $_temporaryOptions.removeSupportedDevices)
			Toggle(.localized("Removed URLScheme"), isOn: $_temporaryOptions.removeURLScheme)
			Toggle(.localized("Supports Document Browser"), isOn: $_temporaryOptions.fileSharing)
			Toggle(.localized("Replace Substrate with ElleKit"), isOn: $_temporaryOptions.experiment_replaceSubstrateWithEllekit)
			Toggle(.localized("Modify configuration only, no signature."), isOn: _modifyOnlyBinding)
			Toggle(.localized("Remove mobileprovision after signing"), isOn: $_temporaryOptions.removeProvisioning)
		} footer: {
			Text(.localized("Replace Substrate with ElleKit rewrites jailbreak dependencies to ElleKit instead of CydiaSubstrate."))
		}
	}
	
	@ViewBuilder
	private func _moreOptions() -> some View {
		NBSection(.localized("More Options")) {
			NavigationLink(.localized("More Options")) {
				Form { SigningOptionsView(
					options: $_temporaryOptions,
					temporaryOptions: _optionsManager.options
				)}
				.navigationTitle(.localized("More Options"))
			}
		} footer: {
			Text(.localized("Appearance, PPQ protection, file sharing, game mode and the rest of the signing options."))
		}
	}
	
	@ViewBuilder
	private func _valueCell<V: View>(_ desc: String?, @ViewBuilder destination: () -> V) -> some View {
		NavigationLink {
			destination()
		} label: {
			Text(desc ?? .localized("Unknown"))
		}
	}
	
	// MARK: - Computed helpers
	
	/// `Feather.compressionLevel` is an index into `ZipCompression.allCases`.
	private var _compressionSpeedIndex: Int {
		ZipCompression.allCases.firstIndex(of: .BestSpeed) ?? 1
	}
	
	private var _compressionBalancedIndex: Int {
		ZipCompression.allCases.firstIndex(of: .DefaultCompression) ?? 2
	}
	
	private var _compressionSizeIndex: Int {
		ZipCompression.allCases.firstIndex(of: .BestCompression) ?? 3
	}
	
	private var _compressionDescription: String {
		if _compressionLevel == _compressionSpeedIndex {
			.localized("Fast compression speed, low compression rate, large files")
		} else if _compressionLevel == _compressionSizeIndex {
			.localized("Slow compression speed, high compression rate, small files")
		} else {
			.localized("Balanced compression speed and file size")
		}
	}
	
	/// ESign's "Set MinimumOSVersion:iOS 10.0" toggle: on means iOS 10.0,
	/// off means the app's own minimum. Any other value picked in the
	/// defaults reads as off here until it is set to 10.0 or Default.
	private var _minimumOSVersionBinding: Binding<Bool> {
		Binding(
			get: { _temporaryOptions.minimumAppRequirement == .v10 },
			set: { _temporaryOptions.minimumAppRequirement = $0 ? .v10 : .default }
		)
	}
	
	/// ESign's "Modify configuration only, no signature." toggle maps to
	/// Feather's `SigningOption.onlyModify`.
	private var _modifyOnlyBinding: Binding<Bool> {
		Binding(
			get: { _temporaryOptions.signingOption == .onlyModify },
			set: { _temporaryOptions.signingOption = $0 ? .onlyModify : .default }
		)
	}
	
	/// The name the signed IPA is saved under, same scheme as
	/// `ArchiveHandler.moveToArchive` (`Name_Version_timestamp.ipa`).
	private var _packageFileName: String {
		let name = _temporaryOptions.appName ?? app.name ?? "App"
		let version = _temporaryOptions.appVersion ?? app.version ?? ""
		return "\(name)_\(version)_\(Int(Date().timeIntervalSince1970)).ipa"
	}
}

// MARK: - Extension: View (import)
extension SigningView {
	private func _start() {
		guard
			_selectedCert() != nil || _temporaryOptions.signingOption != .default
		else {
			UIAlertController.showAlertWithOk(
				title: .localized("No Certificate"),
				message: .localized("Please go to settings and import a valid certificate"),
				isCancel: true
			)
			return
		}

		let generator = UIImpactFeedbackGenerator(style: .light)
		generator.impactOccurred()
		_isSigning = true
		
		FR.signPackageFile(
			app,
			using: _temporaryOptions,
			icon: appIcon,
			certificate: _selectedCert()
		) { error in
			if let error {
				let ok = UIAlertAction(title: .localized("Dismiss"), style: .cancel) { _ in
					dismiss()
				}
				
				UIAlertController.showAlert(
					title: "Error",
					message: error.localizedDescription,
					actions: [ok]
				)
			} else {
				if
					_temporaryOptions.post_deleteAppAfterSigned,
					!app.isSigned
				{
					Storage.shared.deleteApp(for: app)
				}
				
				if _temporaryOptions.post_installAppAfterSigned {
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
						NotificationCenter.default.post(name: Notification.Name("Feather.installApp"), object: nil)
					}
				}
				dismiss()
			}
		}
	}
}
