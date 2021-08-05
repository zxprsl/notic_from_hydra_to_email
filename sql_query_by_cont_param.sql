--SQL-запрос для поиска ДОУ, у которых через N дней закончится срок действия
WITH DOCUMENTS AS ( SELECT  DS.N_SUBJECT_ID,
                            JR.VC_BASE_SUBJECT_NAME,
                            JR.VC_CODE USER_CODE,
                            CJ.N_DOC_ID,
                            CJ.VC_CODE,
                            CJ.VC_REM,
                            DV.D_VALUE
                    FROM    
                            SD_V_CONTRACTS_JR CJ,
                            SI_V_DOC_SUBJECTS DS,
                            SD_V_DOC_VALUES DV,
                            SI_V_USERS JR
                    WHERE   Cj.N_DOC_STATE_ID = SYS_CONTEXT('CONST','DOC_STATE_Actual')
                    AND     DS.N_DOC_ID = DV.N_DOC_ID
                    AND     CJ.N_DOC_ID = DS.N_DOC_ID
                    AND     JR.N_SUBJECT_ID = DS.N_SUBJECT_ID
                    AND     DV.VC_DOC_VALUE_TYPE_CODE = 'END_DATE_OF_CONTRACT'
),
 
DOP_DOCUMENTS AS (      SELECT  d2.N_SUBJECT_ID,
                                d2.VC_BASE_SUBJECT_NAME,
                                d2.VC_CODE USER_CODE,
                                d1.N_DOC_ID,
                                d1.VC_CODE,
                                d1.VC_REM,
                                d2.D_VALUE
                        FROM sd_v_documents d1
                        left join DOCUMENTS d2 ON d1.n_parent_doc_id = d2.n_doc_id
                        WHERE d2.N_SUBJECT_ID IS NOT NULL
                        AND D1.N_DOC_STATE_ID = SYS_CONTEXT('CONST','DOC_STATE_Actual')
                        AND D2.D_VALUE > SYSDATE
      ),
 
ENDED_DOCUMENTS AS (    SELECT *
                        FROM DOCUMENTS
                        WHERE D_VALUE > SYSDATE
 
                        UNION
 
                        SELECT *
                        FROM DOP_DOCUMENTS
                    ),
 
subjects AS (
                SELECT DISTINCT N_SUBJECT_ID
                FROM ENDED_DOCUMENTS
            ),
 
groups AS   (
                SELECT N_SUBJECT_ID
                FROM SI_V_SUBJ_GROUPS
                WHERE (vc_name LIKE 'АО_%' OR vc_name LIKE 'КМ_%' OR vc_name LIKE 'УРП_%')
            ),
 
codes AS (  SELECT  d.N_SUBJECT_ID,   
                    LISTAGG(SI_SUBJECTS_PKG_S.GET_VC_CODE(G.N_SUBJ_GROUP_ID), ', ') WITHIN GROUP (ORDER BY SI_SUBJECTS_PKG_S.GET_VC_CODE(G.N_SUBJ_GROUP_ID) DESC) G_CODES
            FROM    subjects d,
                    SI_V_SUBJECT_BIND_GROUPS G,
                    groups gs
            WHERE   d.N_SUBJECT_ID = g.n_subject_id
            AND     gs.n_subject_id = g.N_SUBJ_GROUP_ID
            GROUP BY d.N_SUBJECT_ID),
 
 
names AS (  SELECT  d.N_SUBJECT_ID,   
                    LISTAGG(SI_SUBJECTS_PKG_S.GET_VC_NAME(G.N_SUBJ_GROUP_ID), ', ') WITHIN GROUP (ORDER BY SI_SUBJECTS_PKG_S.GET_VC_NAME(G.N_SUBJ_GROUP_ID) DESC) G_NAMES
            FROM    subjects d,
                    SI_V_SUBJECT_BIND_GROUPS G,
                    groups gs
            WHERE   d.N_SUBJECT_ID = g.n_subject_id
            AND     gs.n_subject_id = g.N_SUBJ_GROUP_ID
            GROUP BY d.N_SUBJECT_ID) 
 
SELECT  D.VC_BASE_SUBJECT_NAME "Юр.лицо",
        D.USER_CODE "Абонент",
        D.VC_CODE "Договр",
        NVL(TO_CHAR(D.VC_REM),'Отсутствует') "Юр.договор",
        D.D_VALUE "Дата окончания",
        n.G_NAMES "Группа",
        c.G_CODES "E-mail"
FROM    ENDED_DOCUMENTS D
LEFT JOIN codes c ON d.N_SUBJECT_ID = c.N_SUBJECT_ID
LEFT JOIN names n ON d.N_SUBJECT_ID = n.N_SUBJECT_ID
WHERE     TRUNC(D.D_VALUE + 1/24/60/60) = TRUNC(SYSDATE) + :day_shift -- В N указать точное количество дней, через которое срок действия оборудования закончится (Указание точной даты)
--WHERE     (D.D_VALUE > SYSDATE AND D.D_VALUE <= TRUNC(SYSDATE) + N) -- В N указать количество дней, для того, чтобы определить интервал от текущей даты, в который должна попасть дата завершения срока действия оборудования
ORDER BY D.N_SUBJECT_ID
