-- Phase 2.3: Create Classification Prompt Function
-- This UDF builds the prompt for Gemini to classify search reasons
-- The prompt includes all merged categories and examples

CREATE OR REPLACE FUNCTION `durango-deflock.FlockML.build_classification_prompt`(reason STRING)
RETURNS STRING AS (
  CONCAT(
    'You are a law enforcement data classifier. Classify the police search reason "', reason, 
    '" into ONE category.\n\n',
    'CATEGORIES:\n',
    '- Property_Crime: theft, burglary, auto theft, stolen vehicle, carjacking, shoplifting, larceny, B&E\n',
    '- Violent_Crime: homicide, murder, assault, battery, robbery, jugging, shooting\n',
    '- Vehicle_Related: hit and run, reckless driving, abandoned vehicle, tag violations\n',
    '- Person_Search: warrant, wanted, apprehension, A&D, fugitive, ATL, BOLO, eluding, fleeing, pursuit\n',
    '- Vulnerable_Persons: missing person, suicide, welfare check, amber alert, child abduction\n',
    '- Drugs: narcotics, meth, drug investigation\n',
    '- Sex_Crime: sexual assault, sex offense\n',
    '- Human_Trafficking: trafficking, exploitation\n',
    '- Domestic_Violence: domestic violence, family violence\n',
    '- Financial_Crime: fraud, scam, identity theft\n',
    '- Stalking: stalking, harassment\n',
    '- Kidnapping: kidnapping, abduction (non-family)\n',
    '- Arson: arson, fire investigation\n',
    '- Weapons_Offense: weapons, firearms\n',
    '- Smuggling: smuggling, contraband\n',
    '- Federal: AOA, fbi, dhs, ice, immigration, postal, atf, interdiction\n',
    '- Administrative: training, test, 10-code\n',
    '- Case_Number: entries that are actually case numbers (contain 24%, 25%, year patterns, at least 5 characters)\n',
    '- Invalid_Reason: generic unhelpful terms (inv, investigation, case, criminal, find, locate, patrol, traffic, person, suspicious, TBD, info, LEO, police, query, n/a, ., single letters) or gibberish\n',
    '- OTHER: if none of the above categories fit\n\n',
    'EXAMPLES:\n',
    'Reason: "stolen vehicle" -> Property_Crime\n',
    'Reason: "homicide investigation" -> Violent_Crime\n',
    'Reason: "warrant service" -> Person_Search\n',
    'Reason: "inv" -> Invalid_Reason\n',
    'Reason: "n/a" -> Invalid_Reason\n',
    'Reason: "." -> Invalid_Reason\n',
    'Reason: "BOLO suspects" -> Person_Search\n',
    'Reason: "drug interdiction" -> Drugs\n',
    'Reason: "missing child" -> Vulnerable_Persons\n\n',
    '----- Now classify this reason:', reason, '-----\n'
  )
);
