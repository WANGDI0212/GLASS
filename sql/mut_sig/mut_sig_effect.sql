/*
Calculate mutational signatures
By Gene
*/
WITH
selected_tumor_pairs AS
(
	SELECT tumor_pair_barcode, tumor_barcode_a, tumor_barcode_b, idh_codel_subtype
	FROM analysis.silver_set ss
	INNER JOIN clinical.subtypes st ON st.case_barcode = ss.case_barcode
),
selected_aliquots AS
(
	SELECT tumor_barcode_a AS aliquot_barcode, idh_codel_subtype, 'P' AS sample_type FROM selected_tumor_pairs
	UNION
	SELECT tumor_barcode_b AS aliquot_barcode, idh_codel_subtype, 'R' AS sample_type FROM selected_tumor_pairs
),
selected_variants AS
(
	SELECT DISTINCT variant_id, va.gene_symbol, variant_effect, (CASE WHEN dg.gene_symbol IS NULL THEN 'Unknown relevance' WHEN dg.gene_symbol IS NOT NULL THEN 'Known cancer driver' ELSE NULL END) AS known_driver_status
	FROM variants.passanno va
	LEFT JOIN ref.dndscv_known_drivers dg ON dg.gene_symbol = va.gene_symbol
	LEFT JOIN variants.variant_classifications vc ON vc.variant_classification = va.variant_classification
	--WHERE has_mut IS TRUE --dg.gene_symbol = 'TP53'
),
selected_variants_aliquots AS
(
	SELECT *
	FROM selected_variants
	CROSS JOIN selected_aliquots
),
selected_effects AS
(
	SELECT DISTINCT variant_effect, known_driver_status
	FROM selected_variants
	ORDER BY 1
),
selected_subtypes AS
(
	SELECT DISTINCT sample_type FROM selected_aliquots
),
variant_contexts AS
(
	SELECT DISTINCT ref_context AS trinucleotide_context, alt
	FROM ref.signature_proba sp
),
variant_contexts_genes AS
(
	SELECT sample_type, known_driver_status, variant_effect, trinucleotide_context, alt
	FROM selected_effects
	CROSS JOIN variant_contexts
	CROSS JOIN selected_subtypes
),
variant_context_counts AS
(	
	SELECT sample_type, known_driver_status, variant_effect, trinucleotide_context, pa.alt, COUNT(*)::integer AS mut_n
	FROM selected_variants sv
	INNER JOIN variants.passanno pa ON pa.variant_id = sv.variant_id
	INNER JOIN variants.passgeno pg ON pg.variant_id = sv.variant_id --AND pg.aliquot_barcode = sv.aliquot_barcode
	INNER JOIN selected_aliquots sa ON sa.aliquot_barcode = pg.aliquot_barcode
	WHERE ssm2_pass_call IS TRUE AND variant_type = 'SNP' AND ad_alt + ad_ref >= 15
	GROUP BY 1,2,3,4,5
),
variant_context_counts_genes AS
(
	SELECT vca.*, COALESCE(mut_n,0) AS mut_n, SUM(COALESCE(mut_n,0)) OVER (PARTITION BY vca.sample_type, vca.variant_effect, vca.known_driver_status) AS mut_n_total
	FROM variant_contexts_genes vca
	LEFT JOIN variant_context_counts vcc ON vcc.sample_type = vca.sample_type AND vcc.variant_effect = vca.variant_effect AND vcc.known_driver_status = vca.known_driver_status AND vcc.trinucleotide_context = vca.trinucleotide_context AND vcc.alt = vca.alt
),
ref_context_array AS
(
	SELECT array_agg(a ORDER BY signature) AS ref_context_arr
	FROM (SELECT signature, array_agg(proba ORDER BY ref_context,alt) a FROM ref.signature_proba sp GROUP BY 1) t
),
context_reconstruction AS
(
	SELECT sample_type,known_driver_status,variant_effect,ref_context_arr,sum(mut_n) AS mut_n, array_agg(mut_n ORDER BY trinucleotide_context,alt), lsqnonneg(ref_context_arr, array_agg(mut_n ORDER BY trinucleotide_context,alt)) AS mut_sigs
	FROM variant_context_counts_genes, ref_context_array
	WHERE mut_n_total > 9
	GROUP BY 1,2,3,4
),
mutsigs AS
(
	SELECT sample_type, known_driver_status, variant_effect, generate_series(1,30) AS signature, mut_n, unnest(mut_sigs) AS abs_score, UNNEST(mut_sigs) / (SELECT SUM(s) FROM UNNEST(mut_sigs) s) AS rel_score
	FROM context_reconstruction
)
SELECT sample_type, known_driver_status, variant_effect, signature, mut_n, abs_score, rel_score
FROM mutsigs
WHERE rel_score > 0
ORDER BY 1, 2, 3, rel_score DESC
--SELECT * FROM variant_context_counts_genes