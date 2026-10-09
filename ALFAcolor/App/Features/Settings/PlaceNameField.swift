import ALFAcolorCore
import AppTheme
import SwiftUI

/// The name of a place as an editable field. The new name is handed over when the user confirms it with return.
/// When the place gets a new name from elsewhere, the field follows it.
struct PlaceNameField: View {
    @Environment(\.theme) private var theme
    let place: Place
    let onCommit: (String) -> Void
    @State private var draft: String

    init(place: Place, onCommit: @escaping (String) -> Void) {
        self.place = place
        self.onCommit = onCommit
        _draft = State(initialValue: place.name)
    }

    var body: some View {
        TextField("places.name", text: $draft)
            .themeText(theme.text(.control))
            .onSubmit { onCommit(draft) }
            .onChange(of: place.name) { _, name in draft = name }
    }
}
