//
//  ConfigurationDictAddView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct ConfigurationDictAddView: View {
	@Environment(\.dismiss) var dismiss
	
	@State private var _newKey = ""
	@State private var _newValue = ""
	@State private var _showOverrideAlert = false
	
	var saveButtonDisabled: Bool {
		_newKey.isEmpty || _newValue.isEmpty
	}
	
	@Binding var dataDict: [String: String]
	var keyLabel: String = .localized("Value")
	var valueLabel: String = .localized("Replacement")
	
	// MARK: Body
	var body: some View {
		NBList(.localized("New")) {
			Section {
				TextField(keyLabel, text: $_newKey)
				TextField(valueLabel, text: $_newValue)
			}
			.autocapitalization(.none)
		}
		.toolbar {
			NBToolbarButton(
				.localized("Save"),
				style: .text,
				placement: .confirmationAction,
				isDisabled: saveButtonDisabled
			) {
				dataDict[_newKey] = _newValue
				OptionsManager.shared.saveOptions()
				dismiss()
			}
		}
	}
}
