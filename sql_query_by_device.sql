--SQL-запрос для поиска оборудования, у которого через N дней закончится срок действия
WITH OBJECTS AS (       SELECT  SS.N_SUBJECT_ID,
                                SS.N_OBJECT_ID,
                                SI_OBJECTS_PKG_S.GET_NAME_BY_ID(SS.N_OBJECT_ID) VC_NAME,
                                SA.D_END OBJECT_END,
                                JR.VC_BASE_SUBJECT_NAME,
                                JR.VC_CODE USER_CODE
                        FROM    SI_V_OBJ_SUBJECTS SS,
                                SI_V_OBJ_ADDRESSES SA,
                                SI_V_USERS JR
                        WHERE   1=1
                        AND     SA.N_OBJECT_ID = SS.N_OBJECT_ID
                        AND     SS.N_SUBJECT_ID = JR.N_SUBJECT_ID
                        AND     SA.N_ADDR_TYPE_ID = SYS_CONTEXT('CONST','ADDR_TYPE_FactPlace') -- Обычный адрес
                        AND     SA.D_END >= SYSDATE  -- На оборудовании есть дата окончания адреса, причем позднее, чем текущая дата
                        AND     SA.C_FL_MAIN = 'Y'  -- Только по основному адресу
            ),
 
SUBJECTS AS (
                SELECT  DISTINCT
                        N_SUBJECT_ID
                FROM    OBJECTS
            ),
 
DOCUMENTS AS (  SELECT  O.N_SUBJECT_ID,
                        D.VC_CODE DOC_CODE,
                        D.VC_REM,
                        O.N_OBJECT_ID
                FROM    OBJECTS O
                LEFT JOIN SI_V_SUBSCRIPTIONS S ON S.N_CUSTOMER_ID = O.N_SUBJECT_ID AND S.N_OBJECT_ID = O.N_OBJECT_ID
                LEFT JOIN SD_V_DOCUMENTS D ON S.N_DOC_ID = D.N_DOC_ID
                WHERE (S.D_END IS NULL OR S.D_END IS NULL) --Подписка активна
            ),
 
groups AS   (
                SELECT N_SUBJECT_ID
                FROM SI_V_SUBJ_GROUPS
                WHERE (vc_name LIKE 'АО_%' OR vc_name LIKE 'КМ_%' OR vc_name LIKE 'УРП_%')
            ),
 
codes AS (  SELECT  d.N_SUBJECT_ID,   
                    LISTAGG(SI_SUBJECTS_PKG_S.GET_VC_CODE(G.N_SUBJ_GROUP_ID), ', ') WITHIN GROUP (ORDER BY SI_SUBJECTS_PKG_S.GET_VC_CODE(G.N_SUBJ_GROUP_ID) DESC) G_CODES
            FROM    SUBJECTS d,
                    SI_V_SUBJECT_BIND_GROUPS G,
                    groups gs
            WHERE   d.N_SUBJECT_ID = g.n_subject_id
            AND     gs.n_subject_id = g.N_SUBJ_GROUP_ID
            GROUP BY d.N_SUBJECT_ID),
 
 
names AS (  SELECT  d.N_SUBJECT_ID,   
                    LISTAGG(SI_SUBJECTS_PKG_S.GET_VC_NAME(G.N_SUBJ_GROUP_ID), ', ') WITHIN GROUP (ORDER BY SI_SUBJECTS_PKG_S.GET_VC_NAME(G.N_SUBJ_GROUP_ID) DESC) G_NAMES
            FROM    SUBJECTS d,
                    SI_V_SUBJECT_BIND_GROUPS G,
                    groups gs
            WHERE   d.N_SUBJECT_ID = g.n_subject_id
            AND     gs.n_subject_id = g.N_SUBJ_GROUP_ID
            GROUP BY d.N_SUBJECT_ID) 
 
SELECT  D.VC_BASE_SUBJECT_NAME "Юр.лицо",
        D.USER_CODE "Абонент",
        NVL(TO_CHAR(DOC.DOC_CODE),'Отсутствует') "Договр",
        NVL(TO_CHAR(DOC.VC_REM),'Отсутствует') "Юр.договор",
        D.VC_NAME "Оборудование",
        D.OBJECT_END "Дата окончания",
        n.G_NAMES "Группа",
        c.G_CODES "E-mail"
FROM    OBJECTS D
LEFT JOIN codes c ON d.N_SUBJECT_ID = c.N_SUBJECT_ID
LEFT JOIN names n ON d.N_SUBJECT_ID = n.N_SUBJECT_ID
LEFT JOIN DOCUMENTS DOC ON DOC.N_SUBJECT_ID = D.N_SUBJECT_ID AND D.N_OBJECT_ID = DOC.N_OBJECT_ID
WHERE     TRUNC(OBJECT_END + 1/24/60/60) = TRUNC(SYSDATE) + :day_shift -- В N указать точное количество дней, через которое срок действия оборудования закончится (Указание точной даты)
--WHERE     (OBJECT_END > SYSDATE AND OBJECT_END <= TRUNC(SYSDATE) + 365) -- В N указать количество дней, для того, чтобы определить интервал от текущей даты, в который должна попасть дата завершения срока действия оборудования
ORDER BY D.N_SUBJECT_ID

