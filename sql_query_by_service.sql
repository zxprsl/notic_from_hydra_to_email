--SQL-запрос для поиска подписок, у которых через N дней закончится срок действия
WITH SUBSCRIPTIONS AS ( SELECT  SUB.N_CUSTOMER_ID,
                                JR.VC_BASE_SUBJECT_NAME,
                                JR.VC_CODE USER_CODE,
                                DOC.VC_CODE DOC_CODE,
                                DOC.VC_REM,
                                SUB.VC_OBJECT,
                                SUB.D_END D_SUB_END,
                                SUB.VC_SERVICE
                        FROM    SI_V_SUBSCRIPTIONS SUB,
                                SI_V_USERS JR,
                                SD_V_DOCUMENTS DOC
                        WHERE   SUB.N_PAR_SUBSCRIPTION_ID IS NULL --Подписка не дочерняя
                        AND     SUB.D_END > SYSDATE --Указана дата окончания подписки
                        AND     SUB.N_CUSTOMER_ID = JR.N_SUBJECT_ID
                        AND     SUB.N_DOC_ID = DOC.N_DOC_ID
),
 
subjects AS (
                SELECT DISTINCT N_CUSTOMER_ID
                FROM SUBSCRIPTIONS
            ),
 
groups AS   (
                SELECT N_SUBJECT_ID
                FROM SI_V_SUBJ_GROUPS
                WHERE (vc_name LIKE 'АО_%' OR vc_name LIKE 'КМ_%' OR vc_name LIKE 'УРП_%')
            ),
 
codes AS (  SELECT  d.N_CUSTOMER_ID,   
                    LISTAGG(SI_SUBJECTS_PKG_S.GET_VC_CODE(G.N_SUBJ_GROUP_ID), ', ') WITHIN GROUP (ORDER BY SI_SUBJECTS_PKG_S.GET_VC_CODE(G.N_SUBJ_GROUP_ID) DESC) G_CODES
            FROM    subjects d,
                    SI_V_SUBJECT_BIND_GROUPS G,
                    groups gs
            WHERE   d.n_customer_id = g.n_subject_id
            AND     gs.n_subject_id = g.N_SUBJ_GROUP_ID
            GROUP BY d.N_CUSTOMER_ID),
 
 
names AS (  SELECT  d.N_CUSTOMER_ID,   
                    LISTAGG(SI_SUBJECTS_PKG_S.GET_VC_NAME(G.N_SUBJ_GROUP_ID), ', ') WITHIN GROUP (ORDER BY SI_SUBJECTS_PKG_S.GET_VC_NAME(G.N_SUBJ_GROUP_ID) DESC) G_NAMES
            FROM    subjects d,
                    SI_V_SUBJECT_BIND_GROUPS G,
                    groups gs
            WHERE   d.n_customer_id = g.n_subject_id
            AND     gs.n_subject_id = g.N_SUBJ_GROUP_ID
            GROUP BY d.N_CUSTOMER_ID) 
 
SELECT  D.VC_BASE_SUBJECT_NAME "Юр.лицо",
        D.USER_CODE "Абонент",
        D.DOC_CODE "Договр",
        D.VC_REM "Юр.договор",
        D.VC_OBJECT "Оборудование",
        D.VC_SERVICE "Подписка",
        D.D_SUB_END "Дата окончания",
        n.G_NAMES "Группа",
        c.G_CODES "E-mail"
FROM    SUBSCRIPTIONS D
LEFT JOIN codes c ON d.N_CUSTOMER_ID = c.N_CUSTOMER_ID
LEFT JOIN names n ON d.N_CUSTOMER_ID = n.N_CUSTOMER_ID
WHERE     TRUNC(D.D_SUB_END + 1/24/60/60) = TRUNC(SYSDATE) + :day_shift -- В N указать точное количество дней, через которое срок оказания услуги закончится (Указание точной даты)
--WHERE     (D.D_SUB_END > SYSDATE AND D.D_SUB_END <= TRUNC(SYSDATE) + N) -- В N указать количество дней, для того, чтобы определить интевал от текущей даты, в который должна попасть дата завершения оказания услуги
ORDER BY D.D_SUB_END
