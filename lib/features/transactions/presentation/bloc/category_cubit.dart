import 'dart:async';
import 'dart:math' as math;

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';

/// State of the custom-categories manager: the categories of the currently
/// selected [CategoryType] plus the latest operation outcome.
///
/// `successOp` is an operation code ('create' | 'update' | 'delete') so the
/// page can localize the toast (same pattern as InstallmentBloc); `error`
/// carries a ready-to-show Persian message (validation or repository failure).
final class CategoryState extends Equatable {
  final CategoryType selectedType;
  final List<CategoryEntity> categories;
  final bool isLoading;
  final String? successOp;
  final String? error;

  const CategoryState({
    this.selectedType = CategoryType.expense,
    this.categories = const [],
    this.isLoading = true,
    this.successOp,
    this.error,
  });

  CategoryState copyWith({
    CategoryType? selectedType,
    List<CategoryEntity>? categories,
    bool? isLoading,
    String? successOp,
    String? error,
    bool clearSuccessOp = false,
    bool clearError = false,
  }) {
    return CategoryState(
      selectedType: selectedType ?? this.selectedType,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      successOp: clearSuccessOp ? null : (successOp ?? this.successOp),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        selectedType,
        categories,
        isLoading,
        successOp,
        error,
      ];
}

/// Watches categories per selected type and exposes create/update/delete.
/// The drift-backed [CategoryRepository.watchCategories] stream re-emits
/// after every write, so the list stays live without manual reloads.
class CategoryCubit extends Cubit<CategoryState> {
  final CategoryRepository _repository;
  StreamSubscription<List<CategoryEntity>>? _subscription;

  CategoryCubit(this._repository) : super(const CategoryState()) {
    _watch(state.selectedType);
  }

  void _watch(CategoryType type) {
    _subscription?.cancel();
    emit(state.copyWith(categories: const [], isLoading: true));
    _subscription = _repository.watchCategories(type: type).listen(
          (categories) => emit(
            state.copyWith(categories: categories, isLoading: false),
          ),
        );
  }

  void selectType(CategoryType type) {
    if (type == state.selectedType) return;
    emit(CategoryState(selectedType: type));
    _watch(type);
  }

  void clearNotifications() => emit(
        state.copyWith(clearSuccessOp: true, clearError: true),
      );

  Future<void> createCategory({
    required String name,
    required int iconCodePoint,
    required String colorHex,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(error: 'نام دسته را وارد کنید.'));
      return;
    }
    if (_nameTaken(trimmed)) {
      emit(state.copyWith(error: 'دسته‌ای با این نام از قبل وجود دارد.'));
      return;
    }

    final now = DateTime.now();
    final result = await _repository.createCategory(
      CategoryEntity(
        id: '',
        name: trimmed,
        type: state.selectedType,
        iconCodePoint: iconCodePoint,
        colorHex: colorHex,
        sortOrder: _nextSortOrder(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    result.fold(
      onSuccess: (_) => emit(state.copyWith(
        successOp: 'create',
        error: null,
      )),
      onFailure: (failure) => emit(state.copyWith(error: failure.message)),
    );
  }

  Future<void> updateCategory({
    required CategoryEntity category,
    required String name,
    required int iconCodePoint,
    required String colorHex,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(error: 'نام دسته را وارد کنید.'));
      return;
    }
    if (_nameTaken(trimmed, excludeId: category.id)) {
      emit(state.copyWith(error: 'دسته‌ای با این نام از قبل وجود دارد.'));
      return;
    }

    final result = await _repository.updateCategory(
      CategoryEntity(
        id: category.id,
        name: trimmed,
        type: category.type,
        iconCodePoint: iconCodePoint,
        iconFontFamily: category.iconFontFamily,
        colorHex: colorHex,
        parentId: category.parentId,
        isBusiness: category.isBusiness,
        sortOrder: category.sortOrder,
        createdAt: category.createdAt,
        updatedAt: DateTime.now(),
        deletedAt: category.deletedAt,
      ),
    );
    result.fold(
      onSuccess: (_) => emit(state.copyWith(
        successOp: 'update',
        error: null,
      )),
      onFailure: (failure) => emit(state.copyWith(error: failure.message)),
    );
  }

  Future<void> deleteCategory(String id) async {
    final result = await _repository.deleteCategory(id);
    result.fold(
      onSuccess: (_) => emit(state.copyWith(
        successOp: 'delete',
        error: null,
      )),
      onFailure: (failure) => emit(state.copyWith(error: failure.message)),
    );
  }

  bool _nameTaken(String name, {String? excludeId}) {
    return state.categories
        .any((c) => c.id != excludeId && c.name.trim() == name);
  }

  int _nextSortOrder() {
    if (state.categories.isEmpty) return 0;
    return state.categories
            .map((c) => c.sortOrder)
            .reduce(math.max) +
        1;
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
