/* Identify first cancers for each patient in 2006-2015 */
DROP TABLE IF EXISTS  matt.cancers;

CREATE TABLE matt.cancers
SELECT 
	cancers.e_patid, 
	cancers.diagnosisdatebest AS diagnosisdate,
	cancers_patient.age,
	cancers_patient.sex,
	cancers.site_icd10_o2,
	cancer_lkup.cancer_site_desc
FROM (
	SELECT cancers.e_patid, MIN(cancers.diagnosisdatebest) AS diagnosisdate
	FROM 18_299_Lyratzopoulos_e2.cancer_registration_tumour AS cancers
	INNER JOIN 18_299_Lyratzopoulos.lookup_core_cancersite AS cancer_lkup
	ON cancers.site_icd10_o2 = cancer_lkup.icd10_4dig
	WHERE cancer_flag = 1
	GROUP BY e_patid
	) AS first_cancers
INNER JOIN 18_299_Lyratzopoulos_e2.cancer_registration_tumour AS cancers
INNER JOIN 18_299_Lyratzopoulos.lookup_core_cancersite AS cancer_lkup
INNER JOIN 18_299_Lyratzopoulos_e2.cancer_registration_patient AS cancers_patient
ON first_cancers.e_patid = cancers.e_patid 
AND first_cancers.diagnosisdate = cancers.diagnosisdatebest
AND cancers.site_icd10_o2 = cancer_lkup.icd10_4dig
AND cancers.e_patid = cancers_patient.e_patid 
AND cancers.e_cr_id = cancers_patient.e_cr_id
WHERE cancer_flag = 1
;

CREATE INDEX `e_patid` ON matt.cancers (`e_patid`);
CREATE INDEX `diagnosisdate` ON matt.cancers (`diagnosisdate`);

SELECT 
	COUNT(*) AS row_n,
	COUNT(DISTINCT(e_patid)) AS id_n
FROM 18_299_Lyratzopoulos_e2.cprd_clinical;

SELECT 
	COUNT(*) AS row_n,
	COUNT(DISTINCT(e_patid)) AS id_n
FROM matt.cancers;


/*
	116934 first cancers in 116036 patients
	UPDATE 63 million rows
			2,870,645 patients
			333,117 cancers in 330,630 patients
*/



/* Now have "first cancers" for each patient
	Can have multiples - we'll ignore that for now (choose at random in Stata)

	Next: 
		-- join to cprd_case_file for crd tod deathdate etc
		-- join to cprd_practice for uts lcd
*/
DROP TABLE IF EXISTS  matt.cancers_cohort;

CREATE TABLE matt.cancers_cohort
SELECT 
	e_patid, 
	age,
	sex,
	imd2015_10,
	diagnosisdate, 
	site_icd10_o2,
	cancer_site_desc,
	deathdate,
	crd,
	uts, 
	tod,
	lcd
FROM (
	SELECT 
		cancers.*,
		imd_2015.imd2015_10,
		patient_file.crd, /* case registration date */
		patient_file.tod, /* transfer out date */
		patient_file.deathdate,
		practice_file.uts, /* Up to standard date */
		practice_file.lcd /* Last collection date */
	FROM matt.cancers AS cancers
	INNER JOIN 18_299_Lyratzopoulos_e2.cprd_random_sample AS sample
	INNER JOIN 18_299_Lyratzopoulos_e2.cprd_practice AS practice_file
	INNER JOIN 18_299_Lyratzopoulos_e2.cprd_linkage_eligibility_gold AS linkage
	INNER JOIN 18_299_Lyratzopoulos_e2.cprd_patient AS patient_file
	INNER JOIN 18_299_Lyratzopoulos_e2.imd_2015
	ON  cancers.e_patid = sample.e_patid
	AND cancers.e_patid = imd_2015.e_patid
	AND cancers.e_patid = patient_file.e_patid
	AND patient_file.e_patid = linkage.e_patid 
	AND linkage.e_pracid = practice_file.e_pracid
) AS cancers_noexcl
/*WHERE diagnosisdate >= crd + 366*/ /* 1 full years of follow-up */
/*AND diagnosisdate >= uts + 366*/ /* symptom period is UTS */
/*AND diagnosisdate <= tod*/ /* while registered with a practice */
/*AND diagnosisdate <= lcd*/ /* while practice has reported data */
;

CREATE INDEX `e_patid` ON matt.cancers_cohort (`e_patid`);
CREATE INDEX `diagnosisdate` ON matt.cancers_cohort (`diagnosisdate`);

SELECT 
	COUNT(*) AS row_n,
	COUNT(DISTINCT(e_patid)) AS id_n
FROM matt.cancers_cohort;

/*
	49773 cancers in 49427 patients
	UPDATE: 24,160 cancers in 23,991 patients, ~50% larger than UKB?

	So approx. 2.5 times Biobank sample size.
*/



/* Import Read v2 codelist */
DROP TABLE IF EXISTS  matt.phenotypes_readv2;

CREATE TABLE matt.phenotypes_readv2 (
	type VARCHAR(255) NOT NULL,
	event_type VARCHAR(255) NOT NULL,
	readcode VARBINARY(64) NOT NULL
);

LOAD DATA LOCAL INFILE 'S:/ECHO_IHI_CPRD/Matt/ACED2_SymptomIncidenceComparison/sql/readv2_full_codelist.csv'
INTO TABLE matt.phenotypes_readv2
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

CREATE INDEX `readcode` ON matt.phenotypes_readv2 (`readcode`);

select * from matt.phenotypes_readv2 ;
show columns from matt.phenotypes_readv2 ;
show columns from 18_299_Lyratzopoulos.lookup_medical ;

/* Create medcode lookup */
DROP TABLE IF EXISTS matt.phenotypes_medcode;

CREATE TABLE matt.phenotypes_medcode
SELECT
	r.type,
	r.event_type,
	m.medcode
FROM matt.phenotypes_readv2 AS r
INNER JOIN 18_299_Lyratzopoulos.lookup_medical m
ON substring(r.readcode,1,5) = substring(m.readcode,1,5)
GROUP BY r.type, r.event_type, m.medcode;

CREATE INDEX `medcode` ON matt.phenotypes_medcode (`medcode`);


/* Check for symptom-medcode duplicates */
SELECT *
FROM (
	SELECT medcode, count(*) AS n
	FROM matt.phenotypes_medcode
	GROUP BY medcode
	) AS multiples
INNER JOIN matt.phenotypes_medcode m
ON m.medcode = multiples.medcode 
WHERE multiples.n >= 2
;


/* Pull out the relevant symptom and test consultations from the GP clinical file */
/* Idea here:
		Take every single cancer in the cohort
		Left join on any 'relevant' GP clinical record
		That means 	(a) cut down to records in cancer patients happening in that year before diagnosis
					(b) cut down to records that match the medcode phenotype above (no longer applied: now take all consultations)
*/
DROP TABLE IF EXISTS matt.gp_any_consultations;

CREATE TABLE matt.gp_any_consultations
SELECT 
	clin.e_patid, 
	clin.medcode,
	c1.diagnosisdate,
	clin.eventdate
FROM 18_299_Lyratzopoulos_e2.cprd_clinical AS clin
INNER JOIN matt.cancers_cohort AS c1
ON clin.e_patid = c1.e_patid
/*WHERE clin.eventdate >= c1.diagnosisdate-365
AND clin.eventdate <= c1.diagnosisdate*/
;

CREATE INDEX `medcode` ON matt.gp_any_consultations (`medcode`);

DROP TABLE IF EXISTS matt.gp_count_consultations;

CREATE TABLE matt.gp_count_consultations
SELECT 
	clin.e_patid, 
	clin.diagnosisdate,
	clin.eventdate
FROM matt.gp_any_consultations as clin
GROUP BY clin.e_patid, clin.diagnosisdate, clin.eventdate
;

DROP TABLE IF EXISTS matt.gp_clinical_consultations;

CREATE TABLE matt.gp_clinical_consultations
SELECT 
	clin.e_patid, 
	clin.diagnosisdate, 
	ph.type,
	ph.event_type,
	clin.eventdate
FROM matt.gp_any_consultations AS clin
INNER JOIN matt.phenotypes_medcode AS ph
ON clin.medcode = ph.medcode
;

CREATE INDEX `e_patid` ON matt.gp_clinical_consultations (`e_patid`);

-- separate test file
DROP TABLE IF EXISTS matt.gp_tests;

CREATE TABLE matt.gp_tests
SELECT 
	test.e_patid, 
	c1.diagnosisdate, 
	ph.type,
	ph.event_type,
	test.eventdate
FROM 18_299_Lyratzopoulos_e2.cprd_test AS test
INNER JOIN matt.cancers_cohort AS c1 
INNER JOIN matt.phenotypes_medcode AS ph
ON test.medcode = ph.medcode
AND c1.e_patid = test.e_patid
;

CREATE INDEX `e_patid` ON matt.gp_tests (`e_patid`);


