import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

@JsonSerializable()
class UserProfile {
  final String id;
  final String phone;
  final String role;
  final String? name;
  final String? businessId;

  UserProfile({
    required this.id,
    required this.phone,
    required this.role,
    this.name,
    this.businessId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}
