import 'package:flutter/material.dart';

import '../models/user_profile.dart';

const ageGroupOptions = <String>['Dítě', 'Dospívající', 'Dospělý', 'Senior'];

const pragueDistrictOptions = <String>[
  'Praha 1',
  'Praha 2',
  'Praha 3',
  'Praha 4',
  'Praha 5',
  'Praha 6',
  'Praha 7',
  'Praha 8',
  'Praha 9',
  'Praha 10',
  'Praha 11',
  'Praha 12',
  'Praha 13',
  'Praha 14',
  'Praha 15',
  'Praha 16',
  'Praha 17',
  'Praha 18',
  'Praha 19',
  'Praha 20',
  'Praha 21',
  'Praha 22',
];

const preferredLanguageOptions = <String>['Čeština', 'Angličtina', 'Ukrajinština'];

class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.initialProfile,
    required this.submitLabel,
    required this.onSubmit,
    this.showPrivacyNote = true,
  });

  final UserProfile initialProfile;
  final String submitLabel;
  final ValueChanged<UserProfile> onSubmit;
  final bool showPrivacyNote;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _emergencyContactNameController;
  late final TextEditingController _emergencyContactPhoneController;
  late final TextEditingController _medicalNotesController;

  late String _ageGroup;
  late UserRole _role;
  late String _district;
  late String _preferredLanguage;
  late bool _needsMedication;
  late bool _hasChildren;
  late bool _hasSeniorAtHome;
  late bool _hasPet;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _displayNameController = TextEditingController(text: profile.displayName);
    _emergencyContactNameController = TextEditingController(text: profile.emergencyContactName);
    _emergencyContactPhoneController = TextEditingController(text: profile.emergencyContactPhone);
    _medicalNotesController = TextEditingController(text: profile.medicalNotes);
    _ageGroup = _optionOrDefault(ageGroupOptions, profile.ageGroup);
    _role = profile.role;
    _district = _optionOrDefault(pragueDistrictOptions, profile.district);
    _preferredLanguage = _optionOrDefault(preferredLanguageOptions, profile.preferredLanguage);
    _needsMedication = profile.needsMedication;
    _hasChildren = profile.hasChildren;
    _hasSeniorAtHome = profile.hasSeniorAtHome;
    _hasPet = profile.hasPet;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _medicalNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'Zobrazované jméno',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Zadejte zobrazované jméno.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _ageGroup,
            decoration: const InputDecoration(labelText: 'Věková skupina', prefixIcon: Icon(Icons.groups_outlined)),
            items: ageGroupOptions.map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _ageGroup = value);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<UserRole>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.shield_outlined)),
            items: UserRole.values.map((role) => DropdownMenuItem(value: role, child: Text(role.czechLabel))).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _role = value);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _district,
            decoration: const InputDecoration(labelText: 'Pražská část', prefixIcon: Icon(Icons.location_city_outlined)),
            items: pragueDistrictOptions.map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _district = value);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _preferredLanguage,
            decoration: const InputDecoration(labelText: 'Preferovaný jazyk', prefixIcon: Icon(Icons.language_outlined)),
            items: preferredLanguageOptions.map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _preferredLanguage = value);
            },
          ),
          const SizedBox(height: 20),
          _ProfileSwitch(title: 'Potřebuji pravidelné léky', value: _needsMedication, onChanged: (value) => setState(() => _needsMedication = value)),
          _ProfileSwitch(title: 'Mám doma děti', value: _hasChildren, onChanged: (value) => setState(() => _hasChildren = value)),
          _ProfileSwitch(title: 'Mám doma seniora', value: _hasSeniorAtHome, onChanged: (value) => setState(() => _hasSeniorAtHome = value)),
          _ProfileSwitch(title: 'Mám domácí zvíře', value: _hasPet, onChanged: (value) => setState(() => _hasPet = value)),
          const SizedBox(height: 14),
          TextFormField(
            controller: _medicalNotesController,
            decoration: const InputDecoration(labelText: 'Zdravotní poznámky', prefixIcon: Icon(Icons.notes_outlined)),
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emergencyContactNameController,
            decoration: const InputDecoration(labelText: 'Jméno nouzového kontaktu', prefixIcon: Icon(Icons.contact_emergency_outlined)),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emergencyContactPhoneController,
            decoration: const InputDecoration(labelText: 'Telefon nouzového kontaktu', prefixIcon: Icon(Icons.phone_outlined)),
            keyboardType: TextInputType.phone,
          ),
          if (widget.showPrivacyNote) ...[
            const SizedBox(height: 20),
            const _PrivacyNote(),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save_outlined),
              label: Text(widget.submitLabel),
            ),
          ),
        ],
      ),
    );
  }

  String _optionOrDefault(List<String> options, String value) => options.contains(value) ? value : options.first;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(
      UserProfile(
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
      ),
    );
  }
}

class _ProfileSwitch extends StatelessWidget {
  const _ProfileSwitch({required this.title, required this.value, required this.onChanged});

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(title), value: value, onChanged: onChanged);
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF101820),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFFFFD166)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Citlivé údaje zůstávají pouze v tomto zařízení.', style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}