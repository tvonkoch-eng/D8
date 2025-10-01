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
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Text("When is your date?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.seaweedGreenGradient)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
