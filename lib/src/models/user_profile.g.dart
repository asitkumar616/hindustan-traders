// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
      id: json['id'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      name: json['name'] as String?,
      businessId: json['businessId'] as String?,
    );

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) => <String, dynamic>{
      'id': instance.id,
      'phone': instance.phone,
      'role': instance.role,
      'name': instance.name,
      'businessId': instance.businessId,
    };
