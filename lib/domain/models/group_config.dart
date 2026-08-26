import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_config.freezed.dart';

@freezed
abstract class GroupConfig with _$GroupConfig {
  const factory GroupConfig({
    required String name,
    String? password,
  }) = _GroupConfig;

  const GroupConfig._();

  /// A group is password-protected only when a non-empty password is set.
  bool get isLocked => password != null && password!.isNotEmpty;
}
