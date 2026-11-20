//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

// MARK: - View
struct SettingsView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	@AppStorage("UGSign.lockVertical") private var _lockVertical: Bool = false
	@State private var _currentIcon: String? = UIApplication.shared.alternateIconName
	
	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>
	
	private var selectedCertificate: CertificatePair? {
		guard
			_storedSelectedCert >= 0,
			_storedSelectedCert < _certificates.count
		else {
			return nil
		}
		return _certificates[_storedSelectedCert]
	}

    
	private let _donationsUrl = "https://github.com/sponsors/claration"
	private let _githubUrl = "https://github.com/claration/Feather"
	// UG Sign's own links (ESign's Website / Telegram rows, UG edition)
	private let _ugSignGithubUrl = "https://github.com/jahid2025usa-gif/UGsign"
	private let _ugSignTelegramUrl = "https://t.me/iosUG1"
	private let _ugSignChannelUrl = "https://t.me/UGios"
    
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Settings")) {
			Form {
				#if !NIGHTLY && !DEBUG
					SettingsDonationCellView(site: _donationsUrl)
				#endif
                
				_feedback()
				
				// ESign card 1: Certificate Management
				NBSection(.localized("Certificate Management")) {
					if let cert = selectedCertificate {
						CertificatesCellView(cert: cert)
					} else {
						Text(.localized("No Certificate"))
							.font(.footnote)
							.foregroundColor(.disabled())
					}
					NavigationLink(destination: CertificatesView()) {
						Label(.localized("Certificate Management"), systemImage: "checkmark.seal")
					}
				} footer: {
					Text(.localized("Add and manage certificates used for signing applications."))
				}
				
				// ESign card 2: Sign Default Config, Archive & Compression, WiFi
				NBSection(.localized("Signing")) {
					NavigationLink(destination: ConfigurationView()) {
						Label(.localized("Sign Default Config"), systemImage: "signature")
					}
					NavigationLink(destination: ArchiveView()) {
						Label(.localized("Archive & Compression"), systemImage: "archivebox")
					}
					NavigationLink(destination: InstallationView()) {
						Label(.localized("WiFi"), systemImage: "wifi")
					}
				} footer: {
					Text(.localized("Default signing options, zip compression levels, and installing over local WiFi."))
				}
				
				// ESign card 3: Theme, Lock Vertical, storage space
				NBSection(.localized("Appearance")) {
					NavigationLink(destination: AppearanceView()) {
						Label(.localized("Theme"), systemImage: "paintbrush")
					}
					NavigationLink(destination: AppIconView(currentIcon: $_currentIcon)) {
						Label(.localized("App Icon"), systemImage: "app.badge")
					}
					Toggle(isOn: $_lockVertical) {
						Label(.localized("Lock Vertical"), systemImage: "lock.rotation")
					}
					NavigationLink(destination: StorageView()) {
						Label(.localized("The storage space"), systemImage: "internaldrive")
					}
				} footer: {
					Text(.localized("Lock Vertical keeps the app in portrait, including on iPad."))
				}
				
				// ESign card 4: community links
				NBSection(.localized("Community")) {
					Button {
						UIApplication.open(URL(string: _ugSignChannelUrl)!)
					} label: {
						Label(.localized("Join Telegram Channel"), systemImage: "megaphone")
					}
					Button {
						UIApplication.open(URL(string: _ugSignTelegramUrl)!)
					} label: {
						Label(.localized("Join Telegram Group"), systemImage: "paperplane")
					}
					Button {
						UIApplication.open(URL(string: _ugSignGithubUrl)!)
					} label: {
						Label(.localized("UG Sign on GitHub"), systemImage: "safari")
					}
				}
                
				_directories()
                
				Section {
					NavigationLink(destination: ResetView()) {
						Label(.localized("Reset"), systemImage: "trash")
					}
				} footer: {
					Text(.localized("Reset the applications sources, certificates, apps, and general contents."))
				}
			}
		}
	}
}

// MARK: - View extension
extension SettingsView {
	@ViewBuilder
	private func _feedback() -> some View {
		Section {
			NavigationLink(destination: AboutView()) {
				Label {
					Text(verbatim: .localized("About %@", arguments: Bundle.main.name))
				} icon: {
					FRAppIconView(size: 23)
				}
			}
            
			Button(.localized("Submit Feedback"), systemImage: "safari") {
				UIApplication.open(URL(string: "\(_githubUrl)/issues/new/choose")!)
			}
			Button(.localized("GitHub Repository"), systemImage: "safari") {
				UIApplication.open(_githubUrl)
			}
		} footer: {
			Text(.localized("If any issues occur within the app please report it via the GitHub repository. When submitting an issue, make sure to submit detailed information."))
		}
	}
    
	@ViewBuilder
	private func _directories() -> some View {
		NBSection(.localized("Misc")) {
			Button(.localized("Open Documents"), systemImage: "folder") {
				UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Archives"), systemImage: "folder") {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Certificates"), systemImage: "folder") {
				UIApplication.open(FileManager.default.certificates.toSharedDocumentsURL()!)
			}
		} footer: {
			Text(.localized("All of the apps files are contained in the documents directory, here are some quick links to these."))
		}
	}
}
