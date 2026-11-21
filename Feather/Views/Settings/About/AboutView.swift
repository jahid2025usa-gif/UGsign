//
//  AboutView.swift
//  UG Sign
//
//  Branding and the small GPL credit required by the license.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct AboutView: View {
	private let _websiteUrl = "https://ios-ug.github.io"
	private let _githubUrl = "https://github.com/jahid2025usa-gif/UGsign"
	private let _licenseUrl = "https://www.gnu.org/licenses/gpl-3.0.html"
	
	// MARK: Body
	var body: some View {
		NBList(.localized("About")) {
			Section {
				VStack(spacing: 10) {
					Image("BrandLogo")
						.resizable()
						.scaledToFit()
						.frame(width: 96, height: 96)
						.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
					
					Text("UG Sign")
						.font(.largeTitle)
						.bold()
						.foregroundStyle(Color(hex: "#0A84FF"))
					
					Text(.localized("by iOS-UG"))
						.font(.footnote)
						.foregroundStyle(.secondary)
					
					HStack(spacing: 4) {
						Text(.localized("Version"))
						Text(Bundle.main.version)
					}
					.font(.footnote)
					.foregroundStyle(.secondary)
				}
				.frame(maxWidth: .infinity)
				.padding(.vertical, 8)
				.listRowBackground(EmptyView())
			}
			
			NBSection(.localized("Links")) {
				Button {
					UIApplication.open(_websiteUrl)
				} label: {
					Label(.localized("UG Sign Website"), systemImage: "safari")
				}
				
				Button {
					UIApplication.open(_githubUrl)
				} label: {
					Label(.localized("Source Code"), systemImage: "chevron.left.forwardslash.chevron.right")
				}
			}
			
			NBSection(.localized("Legal")) {
				Text(.localized("UG Sign is free and open source. It is based on Feather and is distributed under the GNU General Public License v3.0."))
					.font(.footnote)
					.foregroundStyle(.secondary)
				
				Button {
					UIApplication.open(_licenseUrl)
				} label: {
					Label(.localized("GNU GPL v3.0 License"), systemImage: "doc.text")
						.font(.footnote)
				}
			}
		}
	}
}
