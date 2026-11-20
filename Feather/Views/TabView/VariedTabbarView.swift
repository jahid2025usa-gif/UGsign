//
//  VariedTabbarView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI

struct VariedTabbarView: View {
	// UG Sign: ask once per launch whether the user has a certificate
	@State private var _isCertificateAlertPresenting = false
	@State private var _didAskAboutCertificate = false
	
	init() {}
	
	var body: some View {
		Group {
			if #available(iOS 18, *) {
				ExtendedTabbarView()
			} else {
				TabbarView()
			}
		}
		.alert(.localized("Do you have a certificate?"), isPresented: $_isCertificateAlertPresenting) {
			Button(.localized("Yes, I have one")) { }
			Button(.localized("No, I need one")) {
				if let url = URL(string: "https://t.me/iosUG1") {
					UIApplication.shared.open(url)
				}
			}
		} message: {
			Text(.localized("UG Sign needs a certificate to sign apps."))
		}
		.onAppear {
			// Only ask once per launch, and only when no certificate is imported.
			// Short delay so the certificate store has finished loading first.
			guard !_didAskAboutCertificate else { return }
			_didAskAboutCertificate = true
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
				if Storage.shared.getAllCertificates().isEmpty {
					_isCertificateAlertPresenting = true
				}
			}
		}
	}
}
