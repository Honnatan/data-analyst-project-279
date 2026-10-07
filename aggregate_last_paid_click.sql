WITH ads AS (
    SELECT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    FROM ya_ads

    UNION ALL

    SELECT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    FROM vk_ads
),

ads_grouped AS (
    SELECT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ads
    GROUP BY
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
),

paid_sessions AS (
    SELECT
        visitor_id,
        visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign
    FROM sessions
    WHERE medium IN (
        'cpc',
        'cpm',
        'cpa',
        'youtube',
        'cpp',
        'tg',
        'social'
    )
),

last_paid_click AS (
    SELECT
        ps.visitor_id,
        ps.visit_date,
        ps.utm_source,
        ps.utm_medium,
        ps.utm_campaign,

        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,

        ROW_NUMBER() OVER (
            PARTITION BY ps.visitor_id
            ORDER BY ps.visit_date DESC
        ) AS rn

    FROM paid_sessions AS ps

    LEFT JOIN leads AS l
        ON ps.visitor_id = l.visitor_id
        AND ps.visit_date <= l.created_at
),

attributed AS (
    SELECT
        visitor_id,
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        lead_id,
        created_at,
        amount,
        closing_reason,
        status_id
    FROM last_paid_click
    WHERE rn = 1
)

SELECT
    DATE(a.visit_date) AS visit_date,

    COUNT(DISTINCT a.visitor_id) AS visitors_count,

    a.utm_source,
    a.utm_medium,
    a.utm_campaign,

    ag.total_cost,

    COUNT(DISTINCT a.lead_id) AS leads_count,

    COUNT(
        DISTINCT CASE
            WHEN a.closing_reason = 'Успешная продажа'
                 OR a.status_id = 142
            THEN a.lead_id
        END
    ) AS purchases_count,

    SUM(
        CASE
            WHEN a.closing_reason = 'Успешная продажа'
                 OR a.status_id = 142
            THEN a.amount
        END
    ) AS revenue

FROM attributed AS a

LEFT JOIN ads_grouped AS ag
    ON DATE(a.visit_date) = ag.campaign_date
    AND a.utm_source = ag.utm_source
    AND a.utm_medium = ag.utm_medium
    AND a.utm_campaign = ag.utm_campaign

GROUP BY
    DATE(a.visit_date),
    a.utm_source,
    a.utm_medium,
    a.utm_campaign,
    ag.total_cost

ORDER BY
    revenue DESC NULLS LAST,
    visit_date ASC,
    visitors_count DESC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC

LIMIT 15;