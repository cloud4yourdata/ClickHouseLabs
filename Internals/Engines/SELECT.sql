SELECT
    -- Identyfikator licznika
    'PL_ENERGA_AMI_' || toString(meter_id) AS device_id,
    -- Czas odczytu co 15 minut
    ts_raw AS event_time,
    -- Kod OBIS (Zużycie całkowite)
    '1.8.0' AS obis_code,
    -- Realistyczne narastające zużycie: 
    -- Podstawa 1000 + (liczba interwałów * średnie zużycie 0.2kWh) + szum losowy
    1000 + (rowNumberInAllBlocks() * 0.2) + (randCanonical() * 0.5) AS value,
    'kWh' AS unit
FROM (
    SELECT 
        arrayJoin(range(1, 6)) AS meter_id,
        arrayJoin(
            -- Generowanie punktów czasowych od 30 dni temu do teraz co 900 sekund (15 min)
            range(
                toUInt32(toDateTime(now() - interval 30 day)), 
                toUInt32(toDateTime(now())), 
                900
            )
        ) AS ts_raw
)
ORDER BY device_id, event_time;