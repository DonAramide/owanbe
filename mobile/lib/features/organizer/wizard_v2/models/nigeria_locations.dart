/// Nigerian states and local government areas for venue filtering.
const kNigeriaStates = <String>[
  'Abuja FCT',
  'Lagos',
  'Ogun',
  'Rivers',
  'Kano',
  'Kaduna',
  'Delta',
  'Edo',
];

const kStateLgas = <String, List<String>>{
  'Lagos': [
    'Eti-Osa',
    'Ikeja',
    'Lagos Island',
    'Lagos Mainland',
    'Surulere',
    'Alimosho',
    'Ikorodu',
  ],
  'Abuja FCT': ['Abuja Municipal', 'Bwari', 'Gwagwalada', 'Kuje'],
  'Ogun': ['Abeokuta South', 'Ifo', 'Sagamu', 'Ado-Odo/Ota'],
  'Rivers': ['Port Harcourt', 'Obio/Akpor', 'Eleme'],
  'Kano': ['Kano Municipal', 'Nassarawa', 'Fagge'],
  'Kaduna': ['Kaduna North', 'Kaduna South', 'Chikun'],
  'Delta': ['Warri South', 'Uvwie', 'Sapele'],
  'Edo': ['Oredo', 'Egor', 'Ikpoba Okha'],
};

List<String> lgasForState(String state) => kStateLgas[state] ?? const [];
