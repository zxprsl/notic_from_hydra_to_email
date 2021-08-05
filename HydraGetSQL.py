#!/usr/bin/python3

import configparser
import re 				        # Работаем с регулярками
import os 
import cx_Oracle  			        # Подключение к БД
import pandas as pd                             # работа с таблицами
import pretty_html_table                        # перевод DataFrame в HTML
import smtplib                                  # работа с SMTP сервером
from email.mime.multipart import MIMEMultipart  # создаём сообщение
from email.mime.text import MIMEText            # вёрстка письма

config = configparser.ConfigParser()
config.read('config.ini', encoding='utf-8-sig')

server = config.get('mail', 'server')
From = config.get('mail', 'From')
To = config.get('mail', 'To')
path_to_files =config.get('DB', 'path_to_sql_file')
ora_server = config.get('DB', 'ora_server')
ora_login = config.get('DB', 'ora_login')
ora_pass = config.get('DB', 'ora_pass')


days = 120

day_shift = {
        'day_shift': days
        }

# Решение пробелмы с кодировкой из-за наличия руссикх символов в SQL запросе, в том числе даже в коментариях
os.environ["NLS_LANG"] = ".AL32UTF8" 

# Соединение с БД
connection = cx_Oracle.connect(ora_login, ora_pass, ora_server)
print("Database version:", connection.version)
print("Encoding:", connection.encoding)

cursor = connection.cursor()


def read_sql_to_pandas(sql_query):
    """
    Читаем SQL-запросы из внешнего файла, передаём в pandas
    """
    result = pd.read_sql(open(path_to_files+sql_query).read(), params = day_shift,  con=connection)
    return result

#params = day_shift,

df_device = read_sql_to_pandas('sql_query_by_contract.sql')
#df_contract = read_sql_to_pandas('sql_query_by_contract.sql')
df_cont_param = read_sql_to_pandas('sql_query_by_cont_param.sql')
df_service = read_sql_to_pandas('sql_query_by_service.sql')
df_dev_param = read_sql_to_pandas('sql_query_by_dev_param.sql')



def get_emil_list(dataflame_data):
    """
    Help for the function not yet create
    """
    df_grp = dataflame_data.groupby(['E-mail'], as_index=False).count() # Группируем плученные данные из БД по полю E-mail
    email_numpy_array = df_grp['E-mail'].values    # Возвращает numpy.ndarray из поля E-mail SQL-запроса
    email_list_str = ', '.join(str(x) for x in email_numpy_array) # Перебираем numpy.ndarray, и через разделитель собираем строку из элементов
    return email_list_str

# Получаем списки почтовых адресов из группиованного поля E-mail
email_str_dev = get_emil_list(df_device)
email_str_serv = get_emil_list(df_service)
#email_str_contr = get_emil_list(df_contract)
email_str_cont_param = get_emil_list(df_cont_param)
email_str_dev_param = get_emil_list(df_dev_param)

# Обработка ошибок. Если нет данных в выборке SQL, то выдаёся сообщение начинающееся с Empty. Регулярками находим это. Если данные есть, то 
# выдаётся сообщение None. Рабочим оказался вариант сравнивать именно с None, т.к. если наоборот, то проблема с типами данных (не разобрался)
# Если обработку не делать, то тоже сваливается в ошибку из за отсутствия данных в выборке
# переделать через try except

def get_html_table(pandas_data_from_sql):
    """
    Обработка ошибок. Если нет данных в выборке SQL, то выдаёся сообщение начинающееся с Empty. Регулярками находим это. Если данные есть, то 
    выдаётся сообщение None. Рабочим оказался вариант сравнивать именно с None, т.к. если наоборот, то проблема с типами данных (не разобрался)
    Если обработку не делать, то тоже сваливается в ошибку из за отсутствия данных в выборке
    переделать через try except
    """
    result = re.match(r'Empty', str(pandas_data_from_sql))
    if str(result) == 'None':
        html_table = pretty_html_table.build_table(pandas_data_from_sql, 'blue_light', 'x-small')
    else:
        html_table = 'Нет данных'
    return html_table


html_table_device = get_html_table(df_device)
#html_table_contract = get_html_table(df_contract)
html_table_cont_param = get_html_table(df_cont_param)
html_table_service = get_html_table(df_service)
html_table_dev_param = get_html_table(df_dev_param)


# подключаемся к SMTP серверу
server = smtplib.SMTP(server)
#server.login('email_login', 'email_password')
 
# создаём письмо
msg = MIMEMultipart('mixed')
msg['Subject'] = 'Hydra уведомления'
msg['From'] = From
msg['To'] = To
#msg['To'] = email_str_dev
#msg['To'] = email_str_serv
##msg['To'] = email_str_contr
#msg['To'] = email_str_cont_param
#msg['To'] = email_str_dev_param

#добавляем в письмо текст и таблицу
html_table = MIMEText('<br><br>Информация за '+str(days)+
		      ' дней до наступления даты окончания по следующим позициям:<br><h3>По Оборудованию</h3>Список рассылки:<br>'+email_str_dev+'<br>'+html_table_device+
#		      '<h3>По Договорам</h3>Список рассылки:<br>'+email_str_contr+'<br>'+html_table_contract+
              '<h3>По Договорам. Доп параметр</h3>Список рассылки:<br>'+email_str_cont_param+'<br>'+html_table_cont_param+
		      '<h3>По Подпискам</h3>Список рассылки:<br>'+email_str_serv+'<br>'+html_table_service+
              '<h3>По Дате окончания БЗ</h3>Список рассылки:<br>'+email_str_dev_param+'<br>'+html_table_dev_param
		      ,'html')
 
msg.attach(html_table)
 
# отправляем письмо
server.send_message(msg)
 
# отключаемся от SMTP сервера
server.quit()




