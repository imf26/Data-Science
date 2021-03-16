######--- 0.1 Conversione dtappello to date
alter table appelli
    add datanuova date null;
update appelli
set appelli.datanuova = str_to_date(dtappello, '%d/%m/%Y');
alter table appelli
    drop dtappello;
alter table appelli
    change datanuova dtappello date null;



######--- 0.2 Conversione dtappello to date
alter table bos_denormalizzato
    add datanuova date null;
update bos_denormalizzato
set bos_denormalizzato.datanuova = str_to_date(dtappello, '%d/%m/%Y');
alter table bos_denormalizzato
    drop dtappello;
alter table bos_denormalizzato
    change datanuova dtappello date null;



######--- 1. 
# Distribuzione del numero degli studenti iscritti nei vari appelli, suddivisa per anni e per corso di laurea

###- DB non normalizzato
select CdS as corso_di_laurea,
       AD as appello,
       year(bos_denormalizzato.dtappello) as anno,
       count(*) as studenti_iscritti
from bos_denormalizzato
group by CdS, AD, year(bos_denormalizzato.dtappello)
order by CdS, AD, year(bos_denormalizzato.dtappello) asc;

###- DB normalizzato
select c.cds             as corso_di_laurea,
       a2.ad             as appello,
       year(a.dtappello) as anno,
       count(i.studente) as studenti_iscritti
from appelli a
         join ad a2 on a.adcod = a2.adcod
         join cds c on a.cdscod = c.cdscod
         join iscrizioni i on a.appcod = i.appcod
group by a2.ad, c.cds, a2.ad, year(a.dtappello)
order by c.cds, a2.ad, year(a.dtappello) asc;


######--- 2. 
# Individuazione della Top-10 degli esami più difficili suddivisi per corso di studi.
# Per esame più difficile si intende l’esame che presenta il tasso di superamento complessivo maggiore,
# considerando tutti gli appelli dell’Anno Accademico. Tasso di superamento è inteso come “numero di studenti
# che hanno superato l’appello” (Tab. Iscrizioni col. Superamento) su “numero di studenti che hanno partecipato
# all’appello” minore.

###– DB non normalizzato
select tab3.CdS,
       tab3.AD,
       tab3.appelli,
       tab3.tasso_di_superamento as tasso_di_superamento,
       tab3.tasso_di_superamento_std as tasso_di_superamento_std
from (
    select tab2.CdS,
           tab2.AD,
           tab2.appelli,
           tab2.tasso_di_superamento,
           tab2.tasso_di_superamento_std,
           @rn := IF(@prev = tab2.CdS, @rn + 1, 1) AS rn,
           @prev := tab2.CdS
    from (
        select tab1.CdS,
               tab1.AD,
               count(*) as appelli,
               avg(tab1.tasso) as tasso_di_superamento,
               coalesce(round(stddev_samp(tab1.tasso),2),0) as tasso_di_superamento_std
        from (
            select b.CdS,
                   b.AD,
                   round((sum(b.Superamento)/count(*))*100, 2) as tasso
            from bos_denormalizzato b
            where b.Superamento = 1 or b.Insufficienza = 1 or b.Ritiro = 1
            group by b.CdS, b.AD, b.dtappello) tab1
        group by tab1.CdS, tab1.AD
        order by tab1.CdS, tasso_di_superamento, tab1.AD) tab2
        join (select @prev := NULL, @rn := 0) vars) tab3
where rn <= 10;

###- DB normalizzato
select c.cds,
       ad.ad,
       tab3.appelli,
       tab3.tasso_di_superamento as tasso_di_superamento,
       tab3.tasso_di_superamento_std as tasso_di_superamento_std
from (
    select tab2.cdscod,
           tab2.adcod,
           tab2.appelli,
           tab2.tasso_di_superamento,
           tab2.tasso_di_superamento_std,
           @rn := IF(@prev = tab2.cdscod, @rn + 1, 1) AS rn,
           @prev := tab2.cdscod
    from (
        select tab1.cdscod,
               tab1.adcod,
               count(*) as appelli,
               avg(tab1.tasso) as tasso_di_superamento,
               coalesce(round(stddev_samp(tab1.tasso),2),0) as tasso_di_superamento_std
        from (
            select a.adcod,
                   a.cdscod,
                   round((sum(i.Superamento)/count(*))*100, 2) as tasso
            from appelli a
                join iscrizioni i on a.appcod = i.appcod
            where i.Superamento = 1 or i.Insufficienza = 1 or i.Ritiro = 1
            group by a.adcod, a.cdscod, a.dtappello) tab1
        group by tab1.cdscod, tab1.adcod
        order by tab1.cdscod, tasso_di_superamento, tab1.adcod) tab2
        join (select @prev := NULL, @rn := 0) vars) tab3
    join ad on tab3.adcod = ad.adcod
    join cds c on tab3.cdscod = c.cdscod
where rn <= 10;

######--- 3.
# Individuazione dei corsi di laurea ad elevato tasso di commitment, ovvero appelli di esami diversi ma del medesimo
# corso di laurea che si sono svolti nello stesso giorno

###- DB non normalizzato
select tab1.CdS,
       tab1.date_disponibili,
       coalesce(tab4.date_con_sovrapposizione, 0) as date_con_sovrapposizione,
       round(coalesce(tab4.date_con_sovrapposizione, 0)/tab1.date_disponibili*100, 2) as commitment
from (
        select b.CdS,
               count(distinct (b.dtappello)) as date_disponibili
        from bos_denormalizzato b
        group by b.CdS) tab1
    join (
        select tab3.CdS,
               count(*) as date_con_sovrapposizione
        from (
            select tab2.CdS,
                   tab2.dtappello,
                   count(*) as sovrapposizioni
            from(
                select b.CdS,
                       b.AdCod,
                       b.dtappello
                from bos_denormalizzato b
                group by b.CdS, b.AdCod, b.dtappello) tab2
            group by tab2.CdS, tab2.dtappello
            having sovrapposizioni > 1) tab3
        group by tab3.CdS) tab4 on tab1.cds = tab4.cds
order by commitment desc;

###- DB normalizzato
select c.cds,
       tab1.date_disponibili,
       coalesce(tab4.date_con_sovrapposizione, 0) as date_con_sovrapposizione,
       round(coalesce(tab4.date_con_sovrapposizione, 0)/tab1.date_disponibili*100, 2) as commitment
from (
    select a.cdscod,
           count(distinct (a.dtappello)) as date_disponibili
    from appelli a
    group by a.cdscod) tab1
join
(select tab3.cdscod,
       count(*) as date_con_sovrapposizione
from (
    select tab2.cdscod,
           tab2.dtappello,
           count(*) as sovrapposizioni
    from(
        select a.cdscod,
               a.adcod,
               a.dtappello
        from appelli a
        group by a.cdscod,a.adcod, a.dtappello) tab2
    group by tab2.cdscod, tab2.dtappello
    having sovrapposizioni > 1) tab3
group by tab3.cdscod) tab4 on tab1.cdscod = tab4.cdscod
join cds c on tab1.cdscod = c.cdscod
order by commitment desc;


######--- 4.
# Individuazione della Top-3 degli esami con media voti maggiore e minore rispettivamente, calcolati per ogni singolo
# corso di studi

###- DB non normalizzato
(
    select tab2.CdS,
           tab2.AD,
           'Hardest' as type,
           tab2.sufficienti,
           tab2.partecipanti,
           tab2.voto_medio
    from (
        select tab1.CdS,
               tab1.AD,
               tab1.sufficienti,
               tab1.partecipanti,
               tab1.voto_medio,
               @rn := IF(@prev = tab1.CdS, @rn + 1, 1) AS rn,
               @prev := tab1.CdS
        from (
            select b.CdS,
                   b.AD,
                   sum(b.Superamento) as sufficienti,
                   count(*) as partecipanti,
                   coalesce(round(sum(b.Voto)/count(*),2),0) as voto_medio
            from bos_denormalizzato b
            where b.Superamento = 1 or b.Insufficienza = 1 or b.Ritiro = 1
            group by b.CdS, b.AD
            having sum(b.Voto) is not null
            order by b.CdS, voto_medio asc, b.AD) tab1
            join (select @prev := NULL, @rn := 0) vars) tab2
    where rn <=3)
union (
    select tab2.CdS,
           tab2.AD,
           'Easiest' as type,
           tab2.sufficienti,
           tab2.partecipanti,
           tab2.voto_medio
    from (
        select tab1.CdS,
               tab1.AD,
               tab1.sufficienti,
               tab1.partecipanti,
               tab1.voto_medio,
               @rn := IF(@prev = tab1.CdS, @rn + 1, 1) AS rn,
               @prev := tab1.CdS
        from (
            select b.CdS,
                   b.AD,
                   sum(b.Superamento) as sufficienti,
                   count(*) as partecipanti,
                   coalesce(round(sum(b.Voto)/count(*),2),0) as voto_medio
            from bos_denormalizzato b
            where b.Superamento = 1 or b.Insufficienza = 1 or b.Ritiro = 1
            group by b.CdS, b.AD
            having sum(b.Voto) is not null
            order by b.CdS, voto_medio desc, b.AD) tab1
            join (select @prev := NULL, @rn := 0) vars) tab2
    where rn <=3)
order by cds, voto_medio;


###- DB normalizzato
(
    select c.cds,
           a.ad,
           'Hardest' as type,
           tab2.sufficienti,
           tab2.partecipanti,
           tab2.voto_medio
    from (
        select tab1.cdscod,
               tab1.adcod,
               tab1.sufficienti,
               tab1.partecipanti,
               tab1.voto_medio,
               @rn := IF(@prev = tab1.cdscod, @rn + 1, 1) AS rn,
               @prev := tab1.cdscod
        from (
            select a.cdscod,
                   a.adcod,
                   sum(i.Superamento) as sufficienti,
                   count(*) as partecipanti,
                   coalesce(round(sum(i.Voto)/count(*),2),0) as voto_medio
            from appelli a
                join iscrizioni i on a.appcod = i.appcod
            where i.Superamento = 1 or i.Insufficienza = 1 or i.Ritiro = 1
            group by a.cdscod, a.adcod
            having sum(i.Voto) is not null
            order by a.cdscod, voto_medio asc, a.adcod) tab1
            join (select @prev := NULL, @rn := 0) vars) tab2
    join cds c on tab2.cdscod = c.cdscod
    join ad a on tab2.adcod = a.adcod
    where rn <=3)
union (
    select c.cds,
           a.ad,
           'Easiest' as type,
           tab2.sufficienti,
           tab2.partecipanti,
           tab2.voto_medio
    from (
        select tab1.cdscod,
               tab1.adcod,
               tab1.sufficienti,
               tab1.partecipanti,
               tab1.voto_medio,
               @rn := IF(@prev = tab1.cdscod, @rn + 1, 1) AS rn,
               @prev := tab1.cdscod
        from (
            select a.cdscod,
                   a.adcod,
                   sum(i.Superamento) as sufficienti,
                   count(*) as partecipanti,
                   coalesce(round(sum(i.Voto)/count(*),2),0) as voto_medio
            from appelli a
                join iscrizioni i on a.appcod = i.appcod
            where i.Superamento = 1 or i.Insufficienza = 1 or i.Ritiro = 1
            group by a.cdscod, a.adcod
            having sum(i.Voto) is not null
            order by a.cdscod, voto_medio desc, a.adcod) tab1
            join (select @prev := NULL, @rn := 0) vars) tab2
    join cds c on tab2.cdscod = c.cdscod
    join ad a on tab2.adcod = a.adcod
    where rn <=3)
order by cds, voto_medio;

######--- 5. 
# Calcolare la distribuzione degli studenti “fast&furious” per corso di studi, ovvero studenti con il rapporto
# “votazione media riportata negli esami superati” su “periodo di attività” maggiore. Per periodo di attività si
# intende il numero di giorni trascorsi tra il primo appello sostenuto (non necessariamente superato) e l’ultimo

###- DB non normalizzato
select tab1.Studente,
       tab1.CdS,
       tab1.StuGen,
       tab2.data_primo_appello,
       tab2.data_ultimo_appello,
       tab2.periodo,
       tab1.esami,
       tab1.media,
       tab1.media/tab2.periodo as rapporto
from (
    select b.Studente,
           b.StuGen,
           b.CdS,
           avg(b.Voto) as media,
           count(*) as esami
    from bos_denormalizzato b
    where b.Voto is not null
    group by b.Studente, b.StuGen, b.CdS
    having esami > 1) tab1
join (
    select b.Studente,
           b.CdS,
           min(dtappello) as data_primo_appello,
           max(dtappello) as data_ultimo_appello,
           datediff(max(dtappello),min(dtappello)) + 1 as periodo
    from bos_denormalizzato b
    group by b.Studente, b.CdS) tab2 on tab1.Studente = tab2.Studente and tab1.CdS = tab2.CdS
order by tab1.CdS, rapporto desc;

###- DB normalizzato
select tab1.Studente,
       c.cds,
       s.genere,
       tab2.data_primo_appello,
       tab2.data_ultimo_appello,
       tab2.periodo,
       tab1.esami,
       tab1.media,
       tab1.media/tab2.periodo as rapporto
from (
    select i.Studente,
           a.cdscod,
           avg(i.Voto) as media,
           count(*) as esami
    from appelli a
        join iscrizioni i on a.appcod = i.appcod
    where i.Voto is not null
    group by i.Studente, a.cdscod
    having esami > 1) tab1
join (
    select i.Studente,
           a.cdscod,
           min(a.dtappello) as data_primo_appello,
           max(a.dtappello) as data_ultimo_appello,
           datediff(max(a.dtappello),min(a.dtappello)) + 1 as periodo
    from appelli a
        join iscrizioni i on a.appcod = i.appcod
    group by i.Studente, a.cdscod) tab2 on tab1.Studente = tab2.Studente and tab1.cdscod = tab2.cdscod
join studenti s on tab1.studente = s.studente
join cds c on tab1.cdscod = c.cdscod
order by c.cds, rapporto desc;


######--- 6. 
# Individuazione della Top-3 degli esami “trial&error”, ovvero esami che richiedono il maggior
# numero di tentativi prima del superamento. Dato uno corso di studi, il rispettivo valore trial&error è dato dalla
# media del numero di tentativi (bocciature) di ogni studente per ogni appello del corso.

###- DB non normalizzato
select tab3.CdS,
       tab3.AD,
       tab3.studenti,
       tab3.totale_tentativi,
       tab3.trial_error
from (
    select tab2.CdS,
           tab2.AD,
           tab2.studenti,
           tab2.totale_tentativi,
           tab2.trial_error,
           @rn := IF(@prev = tab2.CdS, @rn + 1, 1) AS rn,
           @prev := tab2.CdS
    from (
        select tab1.CdS,
               tab1.AD,
               count(*) as studenti,
               sum(tab1.tentativi) as totale_tentativi,
               avg(tab1.tentativi) as trial_error
        from (
            select b.CdS,
                   b.AD,
                   sum(b.Superamento+b.Insufficienza+b.Ritiro) as tentativi
            from bos_denormalizzato b
            group by b.Studente, b.AD, b.CdS
            having tentativi > 0) tab1
        group by tab1.CdS, tab1.AD
        having studenti > 1
        order by tab1.CdS, trial_error desc, tab1.AD) tab2
        join (select @prev := NULL, @rn := 0) vars) tab3
where rn <= 3;

###- DB normalizzato
select c.cds,
       a.ad,
       tab3.studenti,
       tab3.totale_tentativi,
       tab3.trial_error
from (
    select tab2.cdscod,
           tab2.adcod,
           tab2.studenti,
           tab2.totale_tentativi,
           tab2.trial_error,
           @rn := IF(@prev = tab2.cdscod, @rn + 1, 1) AS rn,
           @prev := tab2.cdscod
    from (
        select tab1.cdscod,
               tab1.adcod,
               count(*) as studenti,
               sum(tab1.tentativi) as totale_tentativi,
               avg(tab1.tentativi) as trial_error
        from (
            select a.cdscod,
                   a.adcod,
                   sum(i.Superamento+i.Insufficienza+i.Ritiro)+1 as tentativi
            from appelli a
                join iscrizioni i on a.appcod = i.appcod
            group by i.Studente, a.adcod, a.cdscod
            having tentativi > 0) tab1
        group by tab1.cdscod, tab1.adcod
        having studenti > 1
        order by tab1.cdscod, trial_error desc, tab1.adcod) tab2
        join (select @prev := NULL, @rn := 0) vars) tab3
    join cds c on tab3.cdscod = c.cdscod
    join ad a on tab3.adcod = a.adcod
where rn <= 3;


######--- 7. 
# Distribuzione della cittadinanza degli studenti non italiani nei vari corsi di studio

###- DB non normalizzato
select tab1.CdS,
       tab1.CittNaz,
       count(*)
from (
    select distinct(b.Studente),
                    b.CdS,
                    b.CittNaz
    from bos_denormalizzato b
    where b.CittNaz <> 'ITALIA') tab1
group by tab1.CdS, tab1.CittNaz
order by tab1.CdS, count(*) desc;

###- DB normalizzato
select tab1.CdS,
       tab1.CittNaz,
       count(*)
from (
    select distinct(i.studente),
                    c.cds,
                    s.cittnaz
    from studenti s
        join iscrizioni i on s.studente = i.studente
        join appelli a on i.appcod = a.appcod
        join cds c on a.cdscod = c.cdscod
    where s.CittNaz <> 'ITALIA') tab1
group by tab1.CdS, tab1.CittNaz
order by tab1.CdS, count(*) desc;







