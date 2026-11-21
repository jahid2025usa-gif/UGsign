//
//  TabbarView.swift
//  UG Sign
//
//  Based on Feather (GPL-3.0).
//

import SwiftUI

struct TabbarView: View {
	@State private var selectedTab: TabEnum = .files
	
	var body: some View {
		TabView(selection: $selectedTab) {
			ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
				TabEnum.view(for: tab)
					.tabItem {
						Label(tab.title, systemImage: tab.icon)
					}
					.tag(tab)
			}
		}
		.tint(Color(hex: "#0A84FF"))
	}
}
