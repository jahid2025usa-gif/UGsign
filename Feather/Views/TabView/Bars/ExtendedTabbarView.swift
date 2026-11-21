//
//  ExtendedTabbarView.swift
//  UG Sign
//
//  Based on Feather (GPL-3.0).
//

import SwiftUI

@available(iOS 18, *)
struct ExtendedTabbarView: View {
	@State private var _selectedTab: TabEnum = .files
	
	var body: some View {
		TabView(selection: $_selectedTab) {
			ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
				Tab(value: tab) {
					TabEnum.view(for: tab)
				} label: {
					Label(tab.title, systemImage: tab.icon)
				}
			}
		}
		.tint(Color(hex: "#0A84FF"))
	}
}
