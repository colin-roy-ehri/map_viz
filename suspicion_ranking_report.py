#!/usr/bin/env python3
"""
Colorado Attorney General Suspicion Ranking Report
Analyzes likelihood of violation of Colorado law prohibiting police assistance in federal immigration cases

Data sources:
- durango-deflock.DurangoPD.October2025_classified
- durango-deflock.FlockML.org_name_rule_based_matches

Risk Factors (increasing suspicion):
1. Agency is participating in ICE collaboration (is_participating_agency = TRUE)
2. No case number provided (case_num is empty/null, redacted OK)
3. Reason is AOA (interagency) or Invalid_Reason/OTHER
4. Combination of above factors
"""

import pandas as pd
from google.cloud import bigquery
import logging
from typing import Dict, List, Tuple
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class SuspicionRankingAnalyzer:
    def __init__(self, project_id: str = 'durango-deflock'):
        """Initialize BigQuery client and analysis parameters"""
        self.client = bigquery.Client(project=project_id)
        self.project_id = project_id

    def fetch_data(self) -> pd.DataFrame:
        """
        Fetch combined data from October2025_classified and org_name_rule_based_matches
        """
        query = """
        SELECT
            c.* EXCEPT (classification_timestamp),
            COALESCE(m.is_participating_agency, FALSE) AS is_participating_agency,
            m.matched_agency,
            m.matched_state,
            m.matched_type
        FROM `durango-deflock.DurangoPD.October2025_classified` c
        LEFT JOIN `durango-deflock.FlockML.org_name_rule_based_matches` m
            ON c.org_name = m.org_name
        """

        logger.info("Fetching data from BigQuery...")
        df = self.client.query(query).to_dataframe()
        logger.info(f"Loaded {len(df)} records")
        return df

    def calculate_suspicion_score(self, row: pd.Series) -> Tuple[float, List[str]]:
        """
        Calculate suspicion score (0-100) based on risk factors

        Risk factors:
        1. Participating agency (+40 points)
        2. No case number (+30 points)
        3. AOA/Interagency reason (+20 points)
        4. Invalid/OTHER reason (+10 points)

        Returns:
            Tuple of (score, list of factors)
        """
        score = 0
        factors = []

        # Factor 1: Participating agency in ICE collaboration
        if row.get('is_participating_agency') == True:
            score += 40
            factors.append('Participating in ICE collaboration')

        # Factor 2: No case number (redacted case numbers are OK)
        case_num = row.get('case_num', '').strip() if pd.notna(row.get('case_num')) else ''
        if not case_num or case_num.lower() in ['', 'null', 'none', 'n/a', 'na']:
            score += 30
            factors.append('No case number provided')
        elif case_num.lower() in ['redacted', 'xxxx', '####', '[redacted]']:
            # Redacted is OK - don't add to score
            pass

        # Factor 3: AOA (Interagency/All Other Agencies)
        reason_category = row.get('reason_category', '').strip() if pd.notna(row.get('reason_category')) else ''
        if reason_category.lower() == 'interagency' or 'aoa' in str(row.get('reason', '')).lower():
            score += 20
            factors.append('AOA/Interagency reason')

        # Factor 4: Invalid reason or OTHER
        reason_bucket = row.get('reason_bucket', '').strip() if pd.notna(row.get('reason_bucket')) else ''
        if reason_bucket in ['Invalid_Reason', 'Case_Number', 'OTHER'] or reason_category == 'OTHER':
            score += 10
            factors.append('Invalid/ambiguous reason')

        # Cap at 100
        score = min(score, 100)

        return score, factors

    def analyze_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Add suspicion scores and factors to dataframe
        """
        logger.info("Calculating suspicion scores...")

        scores = []
        factor_lists = []

        for _, row in df.iterrows():
            score, factors = self.calculate_suspicion_score(row)
            scores.append(score)
            factor_lists.append('|'.join(factors) if factors else 'None')

        df['suspicion_score'] = scores
        df['risk_factors'] = factor_lists

        return df

    def generate_summary_statistics(self, df: pd.DataFrame) -> Dict:
        """
        Generate summary statistics for the report
        """
        stats = {
            'total_searches': len(df),
            'unique_agencies': df['org_name'].nunique(),
            'participating_agencies': df[df['is_participating_agency'] == True]['org_name'].nunique(),
            'participating_searches': (df['is_participating_agency'] == True).sum(),
            'participating_pct': round((df['is_participating_agency'] == True).sum() / len(df) * 100, 2),

            # Suspicion score distribution
            'zero_suspicion': (df['suspicion_score'] == 0).sum(),
            'low_suspicion': ((df['suspicion_score'] > 0) & (df['suspicion_score'] <= 30)).sum(),
            'moderate_suspicion': ((df['suspicion_score'] > 30) & (df['suspicion_score'] <= 60)).sum(),
            'high_suspicion': ((df['suspicion_score'] > 60) & (df['suspicion_score'] < 100)).sum(),
            'very_high_suspicion': (df['suspicion_score'] == 100).sum(),

            # Case number statistics
            'searches_with_case_number': df[df['case_num'].notna() & (df['case_num'] != '')].shape[0],
            'searches_without_case_number': df[df['case_num'].isna() | (df['case_num'] == '')].shape[0],

            # Reason distribution
            'aoa_searches': df[df['reason_category'] == 'Interagency'].shape[0],
            'invalid_reason_searches': df[df['reason_bucket'].isin(['Invalid_Reason', 'Case_Number', 'OTHER'])].shape[0],
            'valid_reason_searches': df[df['reason_bucket'] == 'Valid_Reason'].shape[0],
        }

        return stats

    def get_high_risk_searches(self, df: pd.DataFrame, min_score: int = 60) -> pd.DataFrame:
        """Get searches with high suspicion scores"""
        high_risk = df[df['suspicion_score'] >= min_score].sort_values('suspicion_score', ascending=False)
        return high_risk[['org_name', 'matched_agency', 'matched_state', 'case_num',
                          'reason', 'reason_category', 'suspicion_score', 'risk_factors']]

    def generate_markdown_report(self, stats: Dict, high_risk_df: pd.DataFrame) -> str:
        """
        Generate markdown formatted report for Attorney General
        """
        report = f"""# Colorado Attorney General
## Suspicion Ranking Report: Potential Violations of State Law
### Police Assistance in Federal Immigration Cases

**Report Generated**: {datetime.now().strftime('%B %d, %Y')}
**Data Period**: October 2025
**Data Source**: Durango Police Department Flock Search Logs

---

## Executive Summary

This analysis examines the likelihood of Colorado law violations regarding police assistance in federal immigration cases. Colorado law prohibits law enforcement agencies from assisting in federal immigration enforcement actions.

**Key Finding**: **{stats['very_high_suspicion']} searches** (out of {stats['total_searches']}) have a **100% suspicion rating** indicating potential violations, with an additional **{stats['high_suspicion']} searches** at high suspicion levels.

---

## Risk Assessment Methodology

Each search is scored based on the following risk factors:

1. **Participating Agency** (+40 points)
   - Agency is known to participate in ICE collaboration via Flock Safety
   - Indicates direct connection to federal immigration enforcement network

2. **No Case Number** (+30 points)
   - Case number absent or not provided
   - Redacted case numbers are acceptable (do not trigger this factor)
   - Absence suggests potential undocumented activity

3. **AOA/Interagency Reason** (+20 points)
   - Search reason classified as "All Other Agencies" or Interagency
   - Suggests coordination with external agencies (potentially federal)

4. **Invalid/Ambiguous Reason** (+10 points)
   - Reason field is invalid, blank, or unclassified
   - Lack of documented legitimate purpose

**Scoring Scale**:
- 0% (0 points): No risk factors present
- Low (1-30): One minor factor
- Moderate (31-60): Multiple factors or one major factor
- High (61-99): Multiple major factors
- Very High (100): Combination of major factors indicating strong suspicion

---

## Overall Statistics

| Metric | Count | Percentage |
|--------|-------|-----------|
| **Total Searches Analyzed** | {stats['total_searches']} | 100% |
| **Unique Agencies** | {stats['unique_agencies']} | — |
| **Participating Agencies** | {stats['participating_agencies']} | — |
| **Searches by Participating Agencies** | {stats['participating_searches']} | {stats['participating_pct']}% |

---

## Suspicion Score Distribution

| Risk Level | Count | Percentage |
|-----------|-------|-----------|
| **0% Suspicion** (No factors) | {stats['zero_suspicion']} | {round(stats['zero_suspicion']/stats['total_searches']*100, 2)}% |
| **Low Suspicion** (1-30%) | {stats['low_suspicion']} | {round(stats['low_suspicion']/stats['total_searches']*100, 2)}% |
| **Moderate Suspicion** (31-60%) | {stats['moderate_suspicion']} | {round(stats['moderate_suspicion']/stats['total_searches']*100, 2)}% |
| **High Suspicion** (61-99%) | {stats['high_suspicion']} | {round(stats['high_suspicion']/stats['total_searches']*100, 2)}% |
| **Very High Suspicion** (100%) | {stats['very_high_suspicion']} | {round(stats['very_high_suspicion']/stats['total_searches']*100, 2)}% |
| **TOTAL HIGH RISK** (60%+) | {stats['high_suspicion'] + stats['very_high_suspicion']} | {round((stats['high_suspicion'] + stats['very_high_suspicion'])/stats['total_searches']*100, 2)}% |

---

## Risk Factor Analysis

### Case Number Compliance

| Status | Count | Percentage |
|--------|-------|-----------|
| **With Case Number** | {stats['searches_with_case_number']} | {round(stats['searches_with_case_number']/stats['total_searches']*100, 2)}% |
| **Without Case Number** | {stats['searches_without_case_number']} | {round(stats['searches_without_case_number']/stats['total_searches']*100, 2)}% |

**Concern**: {stats['searches_without_case_number']} searches lack case numbers, which may indicate undocumented activity.

### Search Reason Classification

| Reason Type | Count | Percentage |
|-----------|-------|-----------|
| **Valid Reasons** | {stats['valid_reason_searches']} | {round(stats['valid_reason_searches']/stats['total_searches']*100, 2)}% |
| **AOA/Interagency** | {stats['aoa_searches']} | {round(stats['aoa_searches']/stats['total_searches']*100, 2)}% |
| **Invalid/Unclassified** | {stats['invalid_reason_searches']} | {round(stats['invalid_reason_searches']/stats['total_searches']*100, 2)}% |

**Concern**: {stats['aoa_searches'] + stats['invalid_reason_searches']} searches ({round((stats['aoa_searches'] + stats['invalid_reason_searches'])/stats['total_searches']*100, 2)}%) lack clearly documented legitimate purposes.

---

## High-Risk Searches (60%+ Suspicion)

The following searches represent the highest potential risk of law violations:

"""

        if len(high_risk_df) > 0:
            report += f"\n**Total High-Risk Searches**: {len(high_risk_df)}\n\n"

            # Top 30 highest risk
            top_risk = high_risk_df.head(30)
            report += "### Top 30 Highest Risk Searches\n\n"
            report += "| Agency | Matched Agency | State | Case # | Reason | Score | Risk Factors |\n"
            report += "|--------|---|---|---|---|---|---|\n"

            for _, row in top_risk.iterrows():
                org = str(row['org_name']).replace('|', ' ')[:30]
                matched = str(row['matched_agency']).replace('|', ' ')[:20] if pd.notna(row['matched_agency']) else "—"
                state = str(row['matched_state']).replace('|', ' ')[:5] if pd.notna(row['matched_state']) else "—"
                case = str(row['case_num']).replace('|', ' ')[:15] if pd.notna(row['case_num']) else "NONE"
                reason = str(row['reason']).replace('|', ' ')[:25] if pd.notna(row['reason']) else "—"
                score = int(row['suspicion_score'])
                factors = str(row['risk_factors']).replace('|', '; ')

                report += f"| {org} | {matched} | {state} | {case} | {reason} | {score}% | {factors} |\n"
        else:
            report += "\nNo high-risk searches found.\n"

        # Recommendations
        report += """

---

## Recommendations for Attorney General

### Immediate Actions

1. **Audit High-Risk Searches** (60%+ suspicion)
   - Request detailed records from participating agencies
   - Verify whether searches were documented with valid case numbers
   - Confirm reasons for searches classified as AOA or Invalid

2. **Participating Agency Oversight**
   - Review Flock Safety participation agreements
   - Verify compliance with Colorado state law restrictions
   - Clarify what constitutes impermissible federal immigration assistance

3. **Case Number Policy**
   - Enforce mandatory case number documentation
   - Distinguish between legitimate case numbers and redactions
   - Establish standards for permissible case number formats

### Longer-term Actions

1. **Data Quality Improvements**
   - Require structured reason codes instead of free-form text
   - Implement validation rules for case number entry
   - Create audit trail for each search

2. **Compliance Framework**
   - Establish clear Colorado-specific guidelines for Flock usage
   - Define which agencies can participate and under what conditions
   - Regular compliance auditing (quarterly)

3. **Training and Documentation**
   - Train officers on state law restrictions
   - Clarify permissible and impermissible use cases
   - Maintain documentation for accountability

---

## Limitations and Caveats

1. **Data Quality**: Analysis depends on accuracy of case numbers and reason classifications
2. **Missing Context**: Without full investigation files, some searches may appear suspicious but be legitimate
3. **Scope**: This analysis focuses only on Flock-based searches; other systems not analyzed
4. **Participation Database**: Matching to participating agencies based on available database (may be incomplete)

---

## Technical Appendix

**Risk Scoring Formula**:
```
Suspicion Score =
    (is_participating_agency * 40) +
    (no_case_number * 30) +
    (aoa_reason * 20) +
    (invalid_reason * 10)

Score is capped at 100 and represents likelihood of violation.
```

**Data Sources**:
- Table: `durango-deflock.DurangoPD.October2025_classified`
- Table: `durango-deflock.FlockML.org_name_rule_based_matches`
- Classification fields: is_participating_agency, case_num, reason_category, reason_bucket

**Report Generated**: {datetime.now().isoformat()}

---

*This report is prepared for the Office of the Colorado Attorney General*
*For questions or additional analysis, contact data.analysis@ag.colorado.gov*
"""

        return report

    def run(self, output_file: str = 'Colorado_AG_Suspicion_Report.md') -> str:
        """
        Run the complete analysis and generate report
        """
        try:
            # Fetch data
            df = self.fetch_data()

            # Calculate suspicion scores
            df = self.analyze_data(df)

            # Generate statistics
            stats = self.generate_summary_statistics(df)

            # Get high-risk searches
            high_risk = self.get_high_risk_searches(df, min_score=60)

            # Generate report
            report = self.generate_markdown_report(stats, high_risk)

            # Save report
            with open(output_file, 'w') as f:
                f.write(report)

            logger.info(f"Report saved to {output_file}")

            # Save detailed data for further analysis
            detailed_file = output_file.replace('.md', '_detailed_data.csv')
            df_export = df[['org_name', 'matched_agency', 'matched_state', 'is_participating_agency',
                            'case_num', 'reason', 'reason_category', 'reason_bucket',
                            'suspicion_score', 'risk_factors']].copy()
            df_export.to_csv(detailed_file, index=False)
            logger.info(f"Detailed data saved to {detailed_file}")

            # Summary statistics
            logger.info(f"\n=== SUMMARY ===")
            logger.info(f"Total searches: {stats['total_searches']}")
            logger.info(f"Very high suspicion (100%): {stats['very_high_suspicion']}")
            logger.info(f"High suspicion (60-99%): {stats['high_suspicion']}")
            logger.info(f"Total high risk (60%+): {stats['high_suspicion'] + stats['very_high_suspicion']}")

            return report

        except Exception as e:
            logger.error(f"Error running analysis: {e}", exc_info=True)
            raise


if __name__ == '__main__':
    analyzer = SuspicionRankingAnalyzer()
    report = analyzer.run(output_file='Colorado_AG_Suspicion_Report.md')
    print("\n✓ Report generated successfully!")
