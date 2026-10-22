import StashCore
import SwiftUI

/// The floating tag picker.
public struct TagPickerView: View {
    let itemId: String
    @ObservedObject var model: PanelViewModel
    public let theme: StashTheme
    var onClose: () -> Void

    @FocusState private var inputFocused: Bool

    public init(
        itemId: String,
        model: PanelViewModel,
        theme: StashTheme,
        onClose: @escaping () -> Void
    ) {
        self.itemId = itemId
        self.model = model
        self.theme = theme
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(theme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if !similar.isEmpty {
                        Text(L10n.t("tagPicker.similar"))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(theme.mutedForeground)
                            .padding(.horizontal, 10)
                            .padding(.top, 8)

                        ForEach(similar, id: \.id) { tag in
                            optionRow(
                                title: L10n.t("tagPicker.use", ["name": tag.name]),
                                icon: "checkmark",
                                isApplied: model.appliedTagSlugs.contains(tag.slug),
                                isHighlighted: false
                            ) {
                                model.toggleTag(slug: tag.slug, name: tag.name)
                            }
                        }

                        Divider().overlay(theme.border).padding(.vertical, 4)
                    }

                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, tag in
                        optionRow(
                            title: tag.name,
                            icon: "tag",
                            isApplied: model.appliedTagSlugs.contains(tag.slug),
                            isHighlighted: model.tagPickerCursor == index
                        ) {
                            model.toggleTag(slug: tag.slug, name: tag.name)
                        }
                    }

                    if canCreate {
                        optionRow(
                            title: L10n.t("tagPicker.create", ["name": model.tagPickerQuery.trimmingCharacters(in: .whitespaces)]),
                            icon: "plus",
                            isApplied: false,
                            isHighlighted: model.tagPickerCursor == filtered.count
                        ) {
                            model.createTag(name: model.tagPickerQuery)
                        }
                    }

                    if filtered.isEmpty && !canCreate {
                        Text(L10n.t("tagPicker.empty"))
                            .font(.system(size: 10))
                            .foregroundColor(theme.mutedForeground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 14)
                    }
                }
                .padding(.bottom, 6)
            }
            .frame(maxHeight: 260)
        }
        .frame(width: 240)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        .onAppear {
            model.appliedTagSlugs = Set(model.tagSlugs(for: itemId))
            DispatchQueue.main.async { inputFocused = true }
        }
        .onChange(of: model.tagPickerQuery) { _ in
            model.tagPickerCursor = 0
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: Symbols.tag)
                .font(.system(size: 11))
                .foregroundColor(theme.mutedForeground)
            TextField(L10n.t("tagPicker.placeholder"), text: $model.tagPickerQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(theme.foreground)
                .focused($inputFocused)
                .onSubmit { model.applyTagPickerCursor() }
                .onExitCommand { onClose() }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Options

    private var filtered: [TagWithCount] {
        model.tagPickerOptions
    }

    private var similar: [Tag] {
        guard !model.tagPickerQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return model.similarTags(to: model.tagPickerQuery)
    }

    private var canCreate: Bool {
        model.tagPickerCanCreate
    }

    private func optionRow(
        title: String,
        icon: String,
        isApplied: Bool,
        isHighlighted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(theme.mutedForeground)
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(theme.foreground)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isApplied {
                    Image(systemName: Symbols.check)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isHighlighted ? theme.muted : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}

/// The inline content editor.
public struct QuickEditView: View {
    let item: ClipboardItem
    public let theme: StashTheme
    var onCancel: () -> Void
    var onSave: (String) -> Void

    @State private var text = ""
    @FocusState private var editorFocused: Bool

    public init(
        item: ClipboardItem,
        theme: StashTheme,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.item = item
        self.theme = theme
        self.onCancel = onCancel
        self.onSave = onSave
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 11))
                    .foregroundColor(theme.mutedForeground)
                Text(L10n.t("panel.quickEdit.title"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.foreground)
                Spacer()
                Button(L10n.t("common.cancel"), action: onCancel)
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(theme.mutedForeground)
                Button(L10n.t("common.save")) {
                    onSave(text)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Divider().overlay(theme.border)

            MonospacedTextEditor(
                text: $text,
                font: .monospacedSystemFont(ofSize: 11, weight: .regular),
                foregroundColor: NSColor(theme.foreground),
                backgroundColor: NSColor(theme.card.opacity(0.4)),
                focusOnAppear: true,
                onExit: { onCancel() },
                onSubmit: { onSave(text) }
            )
            .onAppear {
                text = item.content
                editorFocused = true
            }
        }
    }
}
