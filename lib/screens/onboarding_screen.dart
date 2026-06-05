import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/profile_storage_service.dart';
import '../widgets/profile_form.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.completedScreen});

  final Widget completedScreen;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _basicFormKey = GlobalKey<FormState>();
  final _storage = ProfileStorageService();
  late final TextEditingController _displayNameController;
  late final TextEditingController _medicalNotesController;
  late final TextEditingController _emergencyContactNameController;
  late final TextEditingController _emergencyContactPhoneController;

  int _pageIndex = 0;
  String _ageGroup = 'Dospělý';
  UserRole _role = UserRole.citizen;
  String _district = 'Praha 1';
  String _preferredLanguage = 'Čeština';
  bool _needsMedication = false;
  bool _hasChildren = false;
  bool _hasSeniorAtHome = false;
  bool _hasPet = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _medicalNotesController = TextEditingController();
    _emergencyContactNameController = TextEditingController();
    _emergencyContactPhoneController = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _displayNameController.dispose();
    _medicalNotesController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: _OnboardingProgress(currentStep: _pageIndex + 1),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _pageIndex = index),
                children: [
                  _WelcomeStep(onContinue: _nextPage),
                  _BasicProfileStep(
                    formKey: _basicFormKey,
                    displayNameController: _displayNameController,
                    ageGroup: _ageGroup,
                    role: _role,
                    district: _district,
                    preferredLanguage: _preferredLanguage,
                    onAgeGroupChanged: (value) => setState(() => _ageGroup = value),
                    onRoleChanged: (value) => setState(() => _role = value),
                    onDistrictChanged: (value) => setState(() => _district = value),
                    onPreferredLanguageChanged: (value) => setState(() => _preferredLanguage = value),
                    onContinue: _validateBasicAndContinue,
                    onBack: _previousPage,
                  ),
                  _HouseholdStep(
                    needsMedication: _needsMedication,
                    hasChildren: _hasChildren,
                    hasSeniorAtHome: _hasSeniorAtHome,
                    hasPet: _hasPet,
                    medicalNotesController: _medicalNotesController,
                    emergencyContactNameController: _emergencyContactNameController,
                    emergencyContactPhoneController: _emergencyContactPhoneController,
                    onNeedsMedicationChanged: (value) => setState(() => _needsMedication = value),
                    onHasChildrenChanged: (value) => setState(() => _hasChildren = value),
                    onHasSeniorAtHomeChanged: (value) => setState(() => _hasSeniorAtHome = value),
                    onHasPetChanged: (value) => setState(() => _hasPet = value),
                    onContinue: _nextPage,
                    onBack: _previousPage,
                  ),
                  _PermissionsStep(isSaving: _isSaving, onFinish: _finishOnboarding, onBack: _previousPage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  void _previousPage() {
    _pageController.previousPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  void _validateBasicAndContinue() {
    if (_basicFormKey.currentState!.validate()) _nextPage();
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isSaving = true);
    final profile = UserProfile(
      displayName: _displayNameController.text.trim(),
      ageGroup: _ageGroup,
      role: _role,
      district: _district,
      emergencyContactName: _emergencyContactNameController.text.trim(),
      emergencyContactPhone: _emergencyContactPhoneController.text.trim(),
      medicalNotes: _medicalNotesController.text.trim(),
      needsMedication: _needsMedication,
      hasChildren: _hasChildren,
      hasSeniorAtHome: _hasSeniorAtHome,
      hasPet: _hasPet,
      preferredLanguage: _preferredLanguage,
    );
    await _storage.completeOnboarding(profile);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => widget.completedScreen));
  }
}

class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: currentStep / 4,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: const Color(0xFF242832),
          ),
        ),
        const SizedBox(width: 12),
        Text('$currentStep / 4'),
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const Icon(Icons.offline_bolt_outlined, size: 56, color: Color(0xFFFFD166)),
        const SizedBox(height: 24),
        Text('Blackout Prague', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 34)),
        const SizedBox(height: 16),
        Text('Aplikace je připravená pomáhat offline během výpadku proudu v Praze.', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        Text(
          'Pomůže šetřit baterii, najít pomoc a připravit komunikaci při přetížení nebo výpadku mobilní sítě.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 56,
          child: FilledButton.icon(onPressed: onContinue, icon: const Icon(Icons.arrow_forward), label: const Text('Začít')),
        ),
      ],
    );
  }
}

class _BasicProfileStep extends StatelessWidget {
  const _BasicProfileStep({
    required this.formKey,
    required this.displayNameController,
    required this.ageGroup,
    required this.role,
    required this.district,
    required this.preferredLanguage,
    required this.onAgeGroupChanged,
    required this.onRoleChanged,
    required this.onDistrictChanged,
    required this.onPreferredLanguageChanged,
    required this.onContinue,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController displayNameController;
  final String ageGroup;
  final UserRole role;
  final String district;
  final String preferredLanguage;
  final ValueChanged<String> onAgeGroupChanged;
  final ValueChanged<UserRole> onRoleChanged;
  final ValueChanged<String> onDistrictChanged;
  final ValueChanged<String> onPreferredLanguageChanged;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Základní profil', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Tyto údaje pomohou aplikaci zobrazit vhodnější krizové informace.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 22),
          TextFormField(
            controller: displayNameController,
            decoration: const InputDecoration(labelText: 'Zobrazované jméno', prefixIcon: Icon(Icons.badge_outlined)),
            validator: (value) => value == null || value.trim().isEmpty ? 'Zadejte zobrazované jméno.' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: ageGroup,
            decoration: const InputDecoration(labelText: 'Věková skupina', prefixIcon: Icon(Icons.groups_outlined)),
            items: ageGroupOptions.map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
            onChanged: (value) {
              if (value != null) onAgeGroupChanged(value);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<UserRole>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.shield_outlined)),
            items: UserRole.values.map((option) => DropdownMenuItem(value: option, child: Text(option.czechLabel))).toList(),
            onChanged: (value) {
              if (value != null) onRoleChanged(value);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: district,
            decoration: const InputDecoration(labelText: 'Pražská část', prefixIcon: Icon(Icons.location_city_outlined)),
            items: pragueDistrictOptions.map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
            onChanged: (value) {
              if (value != null) onDistrictChanged(value);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: preferredLanguage,
            decoration: const InputDecoration(labelText: 'Preferovaný jazyk', prefixIcon: Icon(Icons.language_outlined)),
            items: preferredLanguageOptions.map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
            onChanged: (value) {
              if (value != null) onPreferredLanguageChanged(value);
            },
          ),
          const SizedBox(height: 24),
          _StepButtons(onBack: onBack, onContinue: onContinue, continueLabel: 'Pokračovat'),
        ],
      ),
    );
  }
}
class _HouseholdStep extends StatelessWidget {
  const _HouseholdStep({
    required this.needsMedication,
    required this.hasChildren,
    required this.hasSeniorAtHome,
    required this.hasPet,
    required this.medicalNotesController,
    required this.emergencyContactNameController,
    required this.emergencyContactPhoneController,
    required this.onNeedsMedicationChanged,
    required this.onHasChildrenChanged,
    required this.onHasSeniorAtHomeChanged,
    required this.onHasPetChanged,
    required this.onContinue,
    required this.onBack,
  });

  final bool needsMedication;
  final bool hasChildren;
  final bool hasSeniorAtHome;
  final bool hasPet;
  final TextEditingController medicalNotesController;
  final TextEditingController emergencyContactNameController;
  final TextEditingController emergencyContactPhoneController;
  final ValueChanged<bool> onNeedsMedicationChanged;
  final ValueChanged<bool> onHasChildrenChanged;
  final ValueChanged<bool> onHasSeniorAtHomeChanged;
  final ValueChanged<bool> onHasPetChanged;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Domácnost a potřeby', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('Citlivé údaje zůstávají pouze v tomto zařízení.', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 18),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Potřebuji pravidelné léky'),
          value: needsMedication,
          onChanged: onNeedsMedicationChanged,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mám doma děti'),
          value: hasChildren,
          onChanged: onHasChildrenChanged,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mám doma seniora'),
          value: hasSeniorAtHome,
          onChanged: onHasSeniorAtHomeChanged,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mám domácí zvíře'),
          value: hasPet,
          onChanged: onHasPetChanged,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: medicalNotesController,
          decoration: const InputDecoration(labelText: 'Zdravotní poznámky', prefixIcon: Icon(Icons.notes_outlined)),
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: emergencyContactNameController,
          decoration: const InputDecoration(labelText: 'Jméno nouzového kontaktu', prefixIcon: Icon(Icons.contact_emergency_outlined)),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: emergencyContactPhoneController,
          decoration: const InputDecoration(labelText: 'Telefon nouzového kontaktu', prefixIcon: Icon(Icons.phone_outlined)),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 24),
        _StepButtons(onBack: onBack, onContinue: onContinue, continueLabel: 'Pokračovat'),
      ],
    );
  }
}

class _PermissionsStep extends StatelessWidget {
  const _PermissionsStep({required this.isSaving, required this.onFinish, required this.onBack});

  final bool isSaving;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Oprávnění a úspora baterie', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 18),
        const _InfoCard(
          icon: Icons.my_location_outlined,
          title: 'Poloha ručně',
          text: 'Poloha bude používaná pouze ručně, aby aplikace zbytečně nevybíjela baterii.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          icon: Icons.hub_outlined,
          title: 'Bluetooth mesh později',
          text: 'Komunikace přes Bluetooth mesh bude přidána později. Teď se nevyžaduje žádné reálné oprávnění.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          icon: Icons.lock_outline,
          title: 'Soukromí',
          text: 'Citlivé údaje zůstávají pouze v tomto zařízení.',
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isSaving ? null : onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Zpět'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: isSaving ? null : onFinish,
                icon: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Dokončit'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFFFD166), size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(text, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButtons extends StatelessWidget {
  const _StepButtons({required this.onBack, required this.onContinue, required this.continueLabel});

  final VoidCallback onBack;
  final VoidCallback onContinue;
  final String continueLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back), label: const Text('Zpět')),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(onPressed: onContinue, icon: const Icon(Icons.arrow_forward), label: Text(continueLabel)),
        ),
      ],
    );
  }
}