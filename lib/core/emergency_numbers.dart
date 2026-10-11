/// National emergency numbers. Numbers change; the UI says "verify locally".
class EmergencyNumbers {
  final String country; // display name
  final String police;
  final String ambulance;
  final String? fire;
  final String? mountainRescue; // only where a dedicated line exists
  final String? note;

  const EmergencyNumbers(
    this.country, {
    required this.police,
    required this.ambulance,
    this.fire,
    this.mountainRescue,
    this.note,
  });
}

const _eu = EmergencyNumbers(
  'European Union',
  police: '112',
  ambulance: '112',
  fire: '112',
);

/// Keyed by ISO 3166-1 alpha-2 code.
const emergencyNumbers = <String, EmergencyNumbers>{
  'IL': EmergencyNumbers(
    'Israel',
    police: '100',
    ambulance: '101',
    fire: '102',
    note: 'Magen David Adom is 101',
  ),
  'TH': EmergencyNumbers(
    'Thailand',
    police: '191',
    ambulance: '1669',
    fire: '199',
    note: 'Tourist police: 1155',
  ),
  'MM': EmergencyNumbers(
    'Myanmar',
    police: '199',
    ambulance: '192',
    fire: '191',
  ),
  'US': EmergencyNumbers('United States', police: '911', ambulance: '911'),
  'CA': EmergencyNumbers('Canada', police: '911', ambulance: '911'),
  'GB': EmergencyNumbers(
    'United Kingdom',
    police: '999',
    ambulance: '999',
    fire: '999',
    note: 'Ask for Mountain Rescue after calling police',
  ),
  'AU': EmergencyNumbers(
    'Australia',
    police: '000',
    ambulance: '000',
    fire: '000',
  ),
  'NZ': EmergencyNumbers('New Zealand', police: '111', ambulance: '111'),
  'JP': EmergencyNumbers(
    'Japan',
    police: '110',
    ambulance: '119',
    fire: '119',
  ),
  'IN': EmergencyNumbers('India', police: '112', ambulance: '112'),
  'NP': EmergencyNumbers(
    'Nepal',
    police: '100',
    ambulance: '102',
    fire: '101',
  ),
  'CH': EmergencyNumbers(
    'Switzerland',
    police: '117',
    ambulance: '144',
    fire: '118',
    mountainRescue: '1414', // Rega air rescue
  ),
  'AT': EmergencyNumbers(
    'Austria',
    police: '133',
    ambulance: '144',
    fire: '122',
    mountainRescue: '140',
  ),
  'DE': _eu,
  'FR': _eu,
  'IT': _eu,
  'ES': _eu,
};

/// Falls back to the EU number 112, which most phones route anywhere.
EmergencyNumbers numbersFor(String? countryCode) =>
    emergencyNumbers[countryCode?.toUpperCase()] ??
    const EmergencyNumbers(
      'Unknown country',
      police: '112',
      ambulance: '112',
      note: '112 works on most phones worldwide',
    );
