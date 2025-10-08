//
//  DateSelectionView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct DateSelectionView: View {
    @Binding var selectedDate: Date
    
    var body: some View {
        VStack(spacing: 20) {
            // Compact title
            Text("When is your date?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.seaweedGreenGradient)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
            
            // Full calendar view
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            .padding(.horizontal, 20)
            
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
