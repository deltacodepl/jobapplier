import requests
from requests_html import HTMLSession
from bs4 import BeautifulSoup
from util.util import *
session = HTMLSession()

def search_nofluff(city, technology, role):
    url = f"https://nofluffjobs.com/pl/?criteria=city%3D{city}%20requirement%3D{technology}%20seniority%3D{role}"

    response = session.get(url)

    response.html.render()

    soup = BeautifulSoup(response.html.html, "html.parser")

    job_listings = soup.find_all("h3", class_="posting-title__position")

    results = []

    for job in job_listings:
        job_title = job.text
        results.append(job_title)

    results.append("Powyższe oferty pochodzą z linku: " + url + "\n")
    return results


