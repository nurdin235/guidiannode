import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../profile/models/profile_models.dart';
import '../../profile/services/profile_api_service.dart';
import 'package:flutter/services.dart';
import '../utils/post_auth_flow.dart';
import '../widgets/auth_scaffold.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({
    super.key,
    required this.bootstrapLocationSharing,
  });

  final bool bootstrapLocationSharing;

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _quarterController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _relationshipController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final currentUser = SessionService.currentUser;
    if (currentUser == null) {
      return;
    }

    final profile = UserProfile.fromJson(currentUser);
    _fullNameController.text = profile.fullName;
    _quarterController.text = profile.neighborhood;
    _contactNameController.text = profile.emergencyContact?.contactName ?? '';
    _contactPhoneController.text = profile.emergencyContact?.phoneNumber ?? '';
    _relationshipController.text = profile.emergencyContact?.relationship ?? '';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _quarterController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile = await ProfileApiService.updateCurrentProfile(
        fullName: _fullNameController.text.trim(),
        neighborhood: _quarterController.text.trim(),
        emergencyContact: EmergencyContactProfile(
          contactName: _contactNameController.text.trim(),
          phoneNumber: _contactPhoneController.text.trim(),
          relationship: _relationshipController.text.trim(),
        ),
      );

      SessionService.updateCurrentUserFields(profile.toSessionUserFields());

      if (!mounted) {
        return;
      }

      StatusSnackbar.show(
        context,
        message: 'Profile completed. GuardianNode is ready.',
      );
      PostAuthFlow.routeAfterVerification(
        context,
        bootstrapLocationSharing: widget.bootstrapLocationSharing,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isSaving = false);
      StatusSnackbar.show(
        context,
        message: error.toString().replaceFirst('Exception: ', ''),
        tone: StatusTone.error,
      );
      return;
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBackButton: false,
      eyebrow: 'Final setup',
      title: 'Complete your emergency profile',
      subtitle:
          'GuardianNode needs your neighborhood and a trusted contact so responders can move faster under pressure.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const InfoBanner(
              title: 'Required before first emergency',
              message:
                  'This information stays tied to your verified account and supports emergency coordination.',
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _fullNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _quarterController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Quarter / neighborhood',
                prefixIcon: Icon(Icons.location_city_outlined),
                hintText: 'For example Up Station or Bambili',
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Enter your neighborhood';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Primary emergency contact',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _contactNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Contact name',
                prefixIcon: Icon(Icons.contact_page_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Enter a contact name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _contactPhoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Contact phone number',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+237 ...',
              ),
              validator: (value) {
                if (value == null || value.trim().length < 8) {
                  return 'Enter a valid contact phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _relationshipController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                prefixIcon: Icon(Icons.people_outline_rounded),
                hintText: 'Parent, sibling, friend, neighbor',
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Describe the relationship';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              text: 'Finish setup',
              icon: Icons.check_circle_outline_rounded,
              isLoading: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
