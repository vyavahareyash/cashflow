import 'package:flutter/material.dart';

import '../theme/theme_constants.dart';

/// Representation of an individual selectable option in [AppChoicePickerField].
class AppChoiceItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;

  const AppChoiceItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.leading,
    this.trailing,
    this.enabled = true,
  });
}

/// A modern, reusable choice picker form field that replaces standard dropdowns.
///
/// Tapping the field opens a mobile-optimized modal bottom sheet with search
/// filtering, clear hierarchy, and smooth selection animations.
class AppChoicePickerField<T> extends FormField<T> {
  final String? label;
  final String? sheetTitle;
  final String? hintText;
  final List<AppChoiceItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enableSearch;
  final String searchHint;
  final Widget Function(BuildContext context, AppChoiceItem<T>? selectedItem)?
  selectedWidgetBuilder;
  final Widget Function(
    BuildContext context,
    AppChoiceItem<T> item,
    bool isSelected,
    VoidCallback onSelect,
  )?
  itemTileBuilder;

  AppChoicePickerField({
    super.key,
    super.initialValue,
    this.label,
    this.sheetTitle,
    this.hintText,
    required this.items,
    this.onChanged,
    super.onSaved,
    super.validator,
    super.enabled = true,
    super.autovalidateMode,
    bool? enableSearch,
    this.searchHint = 'Search...',
    this.selectedWidgetBuilder,
    this.itemTileBuilder,
  }) : enableSearch = enableSearch ?? (items.length > 5),
       super(
         builder: (FormFieldState<T> state) {
           final context = state.context;
           final isDark = Theme.of(context).brightness == Brightness.dark;
           final borderColor = state.hasError
               ? AppColors.danger
               : (isDark ? AppColors.darkBorder : AppColors.gray300);
           final fillColor = isDark ? AppColors.darkSurface : AppColors.gray50;
           final textColor = isDark ? AppColors.darkText : AppColors.gray900;
           final hintColor = isDark ? AppColors.gray500 : AppColors.gray400;

           final selectedItem = items.cast<AppChoiceItem<T>?>().firstWhere(
             (item) => item?.value == state.value,
             orElse: () => null,
           );

           void showPicker() async {
             if (!enabled) return;

             final selected = await showModalBottomSheet<AppChoiceItem<T>>(
               context: context,
               isScrollControlled: true,
               useSafeArea: true,
               backgroundColor: Colors.transparent,
               builder: (modalCtx) => _ChoicePickerSheet<T>(
                 title:
                     sheetTitle ??
                     (label != null ? 'Select $label' : 'Select Option'),
                 items: items,
                 selectedValue: state.value,
                 enableSearch: enableSearch ?? (items.length > 5),
                 searchHint: searchHint,
                 itemTileBuilder: itemTileBuilder,
               ),
             );

             if (selected != null) {
               state.didChange(selected.value);
               onChanged?.call(selected.value);
             }
           }

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             mainAxisSize: MainAxisSize.min,
             children: [
               if (label != null) ...[
                 Text(
                   label,
                   style: AppTypography.labelMedium.copyWith(
                     color: isDark ? AppColors.gray300 : AppColors.gray700,
                     fontWeight: FontWeight.w600,
                   ),
                 ),
                 const SizedBox(height: AppSpacing.xs),
               ],
               InkWell(
                 onTap: enabled ? showPicker : null,
                 borderRadius: AppBorderRadius.mediumBorder,
                 child: Container(
                   padding: const EdgeInsets.symmetric(
                     horizontal: AppSpacing.lg,
                     vertical: AppSpacing.md,
                   ),
                   decoration: BoxDecoration(
                     color: fillColor,
                     borderRadius: AppBorderRadius.mediumBorder,
                     border: Border.all(
                       color: borderColor,
                       width: state.hasError ? 1.5 : 1.0,
                     ),
                   ),
                   child: Row(
                     children: [
                       Expanded(
                         child: selectedWidgetBuilder != null
                             ? selectedWidgetBuilder(context, selectedItem)
                             : _buildDefaultSelectedWidget(
                                 selectedItem,
                                 hintText,
                                 textColor,
                                 hintColor,
                               ),
                       ),
                       const SizedBox(width: AppSpacing.sm),
                       Icon(
                         Icons.keyboard_arrow_down_rounded,
                         color: isDark ? AppColors.gray400 : AppColors.gray600,
                         size: 22,
                       ),
                     ],
                   ),
                 ),
               ),
               if (state.hasError) ...[
                 const SizedBox(height: AppSpacing.xs),
                 Padding(
                   padding: const EdgeInsets.only(left: AppSpacing.xs),
                   child: Text(
                     state.errorText ?? '',
                     style: AppTypography.bodySmall.copyWith(
                       color: AppColors.danger,
                     ),
                   ),
                 ),
               ],
             ],
           );
         },
       );

  static Widget _buildDefaultSelectedWidget<T>(
    AppChoiceItem<T>? item,
    String? hintText,
    Color textColor,
    Color hintColor,
  ) {
    if (item == null) {
      return Text(
        hintText ?? 'Select an option',
        style: AppTypography.bodyMedium.copyWith(color: hintColor),
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.leading != null) ...[
          item.leading!,
          const SizedBox(width: AppSpacing.sm),
        ] else if (item.icon != null) ...[
          Icon(
            item.icon,
            size: 18,
            color: item.iconColor ?? AppColors.emerald600,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            item.label,
            style: AppTypography.bodyLarge.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ChoicePickerSheet<T> extends StatefulWidget {
  final String title;
  final List<AppChoiceItem<T>> items;
  final T? selectedValue;
  final bool enableSearch;
  final String searchHint;
  final Widget Function(
    BuildContext context,
    AppChoiceItem<T> item,
    bool isSelected,
    VoidCallback onSelect,
  )?
  itemTileBuilder;

  const _ChoicePickerSheet({
    super.key,
    required this.title,
    required this.items,
    this.selectedValue,
    required this.enableSearch,
    required this.searchHint,
    this.itemTileBuilder,
  });

  @override
  State<_ChoicePickerSheet<T>> createState() => _ChoicePickerSheetState<T>();
}

class _ChoicePickerSheetState<T> extends State<_ChoicePickerSheet<T>> {
  late final TextEditingController _searchCtrl;
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.darkSurface : AppColors.white;
    final filteredItems = widget.items.where((item) {
      if (_filterQuery.trim().isEmpty) return true;
      final q = _filterQuery.toLowerCase();
      final labelMatch = item.label.toLowerCase().contains(q);
      final subMatch =
          item.subtitle != null && item.subtitle!.toLowerCase().contains(q);
      return labelMatch || subMatch;
    }).toList();

    return Material(
      color: sheetBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.gray700 : AppColors.gray300,
                borderRadius: AppBorderRadius.pillBorder,
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTypography.titleLarge.copyWith(
                        color: isDark ? AppColors.darkText : AppColors.gray900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ],
              ),
            ),

            // Search Field
            if (widget.enableSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: false,
                  onChanged: (val) => setState(() => _filterQuery = val),
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.gray900,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: isDark ? AppColors.gray500 : AppColors.gray400,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: isDark ? AppColors.gray400 : AppColors.gray500,
                    ),
                    suffixIcon: _filterQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _filterQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.gray100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: AppBorderRadius.mediumBorder,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

            const Divider(height: 1, thickness: 1),

            // Choice Items List
            Flexible(
              child: filteredItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Center(
                        child: Text(
                          'No matches found',
                          style: AppTypography.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.gray500
                                : AppColors.gray400,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xxs),
                      itemBuilder: (ctx, index) {
                        final item = filteredItems[index];
                        final isSelected = item.value == widget.selectedValue;
                        void onSelect() => Navigator.of(context).pop(item);

                        if (widget.itemTileBuilder != null) {
                          return widget.itemTileBuilder!(
                            ctx,
                            item,
                            isSelected,
                            onSelect,
                          );
                        }

                        return Material(
                          color: isSelected
                              ? (isDark
                                    ? AppColors.emerald900.withValues(
                                        alpha: 0.35,
                                      )
                                    : AppColors.emerald50)
                              : Colors.transparent,
                          borderRadius: AppBorderRadius.mediumBorder,
                          child: InkWell(
                            onTap: item.enabled ? onSelect : null,
                            borderRadius: AppBorderRadius.mediumBorder,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.md,
                              ),
                              child: Row(
                                children: [
                                  if (item.leading != null) ...[
                                    item.leading!,
                                    const SizedBox(width: AppSpacing.md),
                                  ] else if (item.icon != null) ...[
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color:
                                            (item.iconColor ??
                                                    AppColors.emerald600)
                                                .withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        item.icon,
                                        size: 18,
                                        color:
                                            item.iconColor ??
                                            AppColors.emerald600,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.label,
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? (isDark
                                                          ? AppColors.emerald300
                                                          : AppColors
                                                                .emerald800)
                                                    : (isDark
                                                          ? AppColors.darkText
                                                          : AppColors.gray900),
                                              ),
                                        ),
                                        if (item.subtitle != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.subtitle!,
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                                  color: isDark
                                                      ? AppColors.gray400
                                                      : AppColors.gray500,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (item.trailing != null) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    item.trailing!,
                                  ],
                                  if (isSelected) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.emerald600,
                                      size: 20,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(
              height: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
            ),
          ],
        ),
      ),
    );
  }
}
