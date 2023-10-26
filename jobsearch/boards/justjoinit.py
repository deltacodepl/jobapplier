from selenium import webdriver
from bs4 import BeautifulSoup
from util.util import *

keywords = ["Developer","Development", "developer","Engineering", "Engineer", "Design", "Designer", "Administrator", "Programmer", "Programista", "Analityk", "Test", "Tester", "Testing", "Application", "DevOps", "Technical", "Specialist", "IT", "Product", "Manager", "Research", "Projektant", "Analyst", "Architect", "Specjalista", "Consultant", "Support", "Admin", "Inżynier", "System", "Konsultant"]

def search_justjoinit(city, technology, role, withSalary, keywords):

    options = webdriver.ChromeOptions()
    options.add_argument('--headless')
    options.add_argument('--disable-extensions')
    options.add_argument('--disable-gpu')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--no-sandbox')
    options.add_argument('start-maximized')
    options.add_argument('disable-infobars')
    options.add_argument('--disable-browser-side-navigation')
    options.add_argument('--disable-gpu-sandbox')

    url = f"https://justjoin.it/{city}/{technology}/{role}?tab=with-salary" if withSalary == 1 else f"https://justjoin.it/{city}/{technology}/{role}"
    
    driver = webdriver.Chrome(options=options)
    driver.get(url)

    soup = BeautifulSoup(driver.page_source, 'html.parser')

    results = []

    for keyword in keywords:
        for div in soup.find_all('div'):
            if keyword in div.text:
                deepest_div = div
                while len(deepest_div.find_all('div')) > 0:
                    deepest_div = deepest_div.find_all('div')[0]
                results.append(deepest_div.text.strip())
    
    driver.quit()

    results.append("Powyższe oferty pochodzą z linku: " + url  + "\n")
    
    return results

# unique filter
def unique(array):
    unique_values = set()
    unique_list = []
    for value in array:
        truncated_value = value[:20]
        if truncated_value not in unique_values:
            unique_values.add(truncated_value)
            unique_list.append(value)
        
    #usuwamy dwa pierwsze elementy przez bug, którego inaczej nie udało się rozwiązać, do listy wpisywał się pusty string i string "With salary"
    del unique_list[0:2]
    return unique_list
