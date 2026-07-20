import SwiftUI

struct CreateTagPopover: View {
  var onCancel: () -> Void
  var onCreate: (String, String) -> Void

  @State private var name = ""
  @State private var color = TidePalette.colors[0]

  var body: some View {
    VStack(alignment: .leading, spacing: 13) {
      Text("创建专注标签")
        .font(.system(size: 16, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .center)

      VStack(alignment: .leading, spacing: 6) {
        Text("标签名称")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.secondary)
        TextField("输入标签名称...", text: $name)
          .textFieldStyle(.roundedBorder)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("标签颜色")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.secondary)
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(39)), count: 4), spacing: 10) {
          ForEach(TidePalette.colors, id: \.self) { hex in
            Button {
              color = hex
            } label: {
              ZStack {
                Circle()
                  .fill(Color(hex: hex))
                  .frame(width: 28, height: 28)
                  .overlay {
                    Circle().stroke(.white.opacity(color == hex ? 0.95 : 0.18), lineWidth: color == hex ? 2 : 1)
                  }
                if color == hex {
                  Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)
                }
              }
              .frame(width: 39, height: 39)
              .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityLabel("颜色 \(hex)")
            .accessibilityValue(color == hex ? "已选择" : "未选择")
          }
        }
      }

      HStack(spacing: 10) {
        Button(action: onCancel) {
          Text("取消")
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
        }
        .clipoCapsuleButton()
        .keyboardShortcut(.cancelAction)
        Button {
          onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines), color)
        } label: {
          Text("添加")
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
        }
        .clipoCapsuleButton(prominent: true)
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(17)
    .frame(width: 240)
    .tideGlassRect(cornerRadius: 20, backingOpacity: 0.92)
    .onExitCommand(perform: onCancel)
  }
}

struct FocusLabelPickerPopover: View {
  var controller: PomodoroController
  var onCreate: () -> Void
  var onClose: () -> Void

  private var visibleCategories: [PomodoroCategory] {
    controller.categories.filter { $0.name != "未命名分组" }
  }

  private var isEmpty: Bool {
    visibleCategories.isEmpty && controller.focusTags.isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("专注标签")
          .font(.system(size: 15, weight: .bold))
        Spacer()
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 11, weight: .bold))
            .frame(width: 27, height: 27)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .tideGlassCircle(interactive: true)
        .accessibilityLabel("关闭标签选择")
      }

      ScrollView(.vertical, showsIndicators: false) {
        TideGlassContainer(spacing: 7) {
          VStack(spacing: 7) {
            ForEach(visibleCategories) { category in
              labelRow(
                name: category.name,
                colorHex: category.colorHex,
                selected: controller.configuration.selectedCategoryID == category.id,
                onDelete: {
                  controller.deleteCategory(id: category.id)
                }
              ) {
                let selected = controller.configuration.selectedCategoryID == category.id
                controller.selectCategory(selected ? nil : category.id)
                onClose()
              }
            }

            ForEach(controller.focusTags) { tag in
              labelRow(
                name: tag.name,
                colorHex: tag.colorHex,
                selected: controller.configuration.selectedTagID == tag.id,
                onDelete: {
                  controller.deleteTag(id: tag.id)
                }
              ) {
                let selected = controller.configuration.selectedTagID == tag.id
                controller.selectTag(selected ? nil : tag.id)
                onClose()
              }
            }

            if isEmpty {
              Text("还没有标签")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, minHeight: 36)
            }

            if controller.selectedFocusLabelName != nil {
              Button {
                controller.selectTag(nil)
                onClose()
              } label: {
                Label("不使用标签", systemImage: "tag.slash")
                  .font(.system(size: 11, weight: .medium))
                  .foregroundStyle(.secondary)
                  .frame(maxWidth: .infinity, minHeight: 32)
                  .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
              }
              .buttonStyle(.plain)
              .focusable(false)
              .tideGlassRect(cornerRadius: 10, interactive: true)
              .accessibilityLabel("清除当前标签选择")
            }
          }
        }
      }
      .frame(maxHeight: 220)

      Button(action: onCreate) {
        Label("新建标签", systemImage: "plus")
          .frame(maxWidth: .infinity)
      }
      .clipoCapsuleButton(prominent: true)
      .accessibilityLabel("新建专注标签")
    }
    .padding(15)
    .frame(width: 250)
    .tideGlassRect(cornerRadius: 18, backingOpacity: 0.74)
    .onExitCommand(perform: onClose)
  }

  private func labelRow(
    name: String,
    colorHex: String,
    selected: Bool,
    onDelete: (() -> Void)? = nil,
    action: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 7) {
      Button(action: action) {
        HStack(spacing: 9) {
          Circle()
            .fill(Color(hex: colorHex))
            .frame(width: 8, height: 8)
          Text(name)
            .font(.system(size: 12, weight: selected ? .semibold : .medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
          Spacer()
          if selected {
            Image(systemName: "checkmark")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(Color.accentColor)
          }
        }
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, minHeight: 34)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      }
      .buttonStyle(.plain)
      .focusable(false)
      .tideGlassRect(
        cornerRadius: 10,
        tint: selected ? Color(hex: colorHex).opacity(0.28) : nil,
        interactive: true
      )
      .accessibilityLabel(name)
      .accessibilityValue(selected ? "已选择" : "未选择")

      if let onDelete {
        Button(role: .destructive, action: onDelete) {
          Image(systemName: "trash")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.red.opacity(0.82))
            .frame(width: 34, height: 34)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .tideGlassRect(
          cornerRadius: 10,
          tint: Color.red.opacity(0.12),
          interactive: true
        )
        .help("删除标签 \(name)")
        .accessibilityLabel("删除标签 \(name)")
      }
    }
  }
}
