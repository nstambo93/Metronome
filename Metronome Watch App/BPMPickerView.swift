import SwiftUI

struct BPMPickerView: View {
    @Binding var selectedBPM: Double
    @Binding var isPresented: Bool

    @State private var tempBPM: Double
    @FocusState private var isFocused: Bool

    init(selectedBPM: Binding<Double>, isPresented: Binding<Bool>) {
        self._selectedBPM = selectedBPM
        self._isPresented = isPresented
        self._tempBPM = State(initialValue: selectedBPM.wrappedValue)
    }

    var body: some View {
        List {
            Picker("BPM", selection: $tempBPM) {
                ForEach(Array(stride(from: 120.0, through: 200.0, by: 5.0)), id: \.self) { value in
                    Text("\(Int(value))")
                        .font(.system(size: 25, weight: .semibold))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(minHeight: 140)
            .focused($isFocused)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    selectedBPM = tempBPM
                    isPresented = false
                } label: {
                    Image(systemName: "checkmark")
                }
//                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(.blue)
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}
