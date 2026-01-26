//
//  CountMeApp.swift
//  CountMe
//
//  Created by Lucas Hahn on 1/19/26.
//

import SwiftUI
import SwiftData

@main
struct CountMeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodItem.self,
            DailyLog.self,
            CustomMeal.self,
            Ingredient.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
