//
//  SettingsView.swift
//  UG Sign
//
//  eSign-style settings screen.
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
	
	private let _websiteUrl = "https://ios-ug.github.io"
	private let _githubUrl = "https://github.com/jahid2025usa-gif/UGsign"
	private let _telegramUrl = "https://t.me/UGios"
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Settings")) {
			Form {
				_certificateSection()
				_signingSection()
				_appearanceSection()
				_communitySection()
				_aboutSection()
			}
		}
	}
}

// MARK: - Sections
extension SettingsView {
	@ViewBuilder
	private func _certificateSection() -> some View {
		Section {
			NavigationLink {
				CertificatesView()
			} label: {
				HStack(spacing: 12) {
					Image(systemName: "checkmark.seal.fill")
						.font(.system(size: 20))
						.foregroundStyle(Color(hex: "#0A84FF"))
						.frame(width: 30)
					
					VStack(alignment: .leading, spacing: 3) {
						Text(.localized("Certificate Management"))
						Text(selectedCertificate?.nickname ?? .localized("No Certificate"))
							.font(.caption)
							.foregroundStyle(.secondary)
							.lineLimit(1)
					}
				}
			}
		} footer: {
			Text(.localized("Add and manage the certificate used to sign applications."))
		}
	}
	
	@ViewBuilder
	private func _signingSection() -> some View {
		NBSection(.localized("Signing")) {
			NavigationLink {
				ConfigurationView()
			} label: {
				Label(.localized("Sign Default Config"), systemImage: "signature")
			}
			
			NavigationLink {
				ArchiveView()
			} label: {
				Label(.localized("Compression"), systemImage: "archivebox")
			}
			
			NavigationLink {
				InstallationView()
			} label: {
				Label(.localized("WiFi"), systemImage: "wifi")
			}
		} footer: {
			Text(.localized("Default signing options, ZIP compression and installing over local WiFi."))
		}
	}
	
	@ViewBuilder
	private func _appearanceSection() -> some View {
		NBSection(.localized("Appearance")) {
			NavigationLink {
				AppearanceView()
			} label: {
				Label(.localized("Theme"), systemImage: "paintbrush")
			}
			
			Toggle(isOn: $_lockVertical) {
				Label(.localized("Lock Vertical"), systemImage: "lock.rotation")
			}
			
			NavigationLink {
				StorageView()
			} label: {
				Label(.localized("The storage space"), systemImage: "internaldrive")
			}
		} footer: {
			Text(.localized("Lock Vertical keeps the app in portrait, including on iPad."))
		}
	}
	
	@ViewBuilder
	private func _communitySection() -> some View {
		NBSection(.localized("Community")) {
			Button {
				UIApplication.open(_telegramUrl)
			} label: {
				Label(.localized("Join Telegram Group"), systemImage: "paperplane")
			}
			
			Button {
				UIApplication.open(_websiteUrl)
			} label: {
				Label(.localized("UG Sign Website"), systemImage: "safari")
			}
			
			Button {
				UIApplication.open(_githubUrl)
			} label: {
				Label(.localized("UG Sign on GitHub"), systemImage: "chevron.left.forwardslash.chevron.right")
			}
		}
	}
	
	@ViewBuilder
	private func _aboutSection() -> some View {
		Section {
			NavigationLink {
				AboutView()
			} label: {
				HStack(spacing: 12) {
					Image("BrandLogo")
						.resizable()
						.scaledToFit()
						.frame(width: 28, height: 28)
						.clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
					Text(verbatim: .localized("About %@", arguments: "UG Sign"))
				}
			}
			
			NavigationLink {
				ResetView()
			} label: {
				Label(.localized("Reset"), systemImage: "trash")
			}
		}
	}
}
