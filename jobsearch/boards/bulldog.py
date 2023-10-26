import requests
from requests_html import HTMLSession
from bs4 import BeautifulSoup
from util.util import *
session = HTMLSession()

def search_bulldog(city, technology, role, salary):
    url = f"https://bulldogjob.pl/companies/jobs/s/experienceLevel{role}/skills{technology}/city{city}/withsalary{salary}"

    response = session.get(url)

    response.html.render()

    soup = BeautifulSoup(response.html.html, "html.parser")

    job_listings = soup.find_all("h3", class_="JobListItem_title__tdmYl")

    results = []

    for job in job_listings:
        job_title = job.text
        results.append(job_title)

    results.append("Powyższe oferty pochodzą z linku: " + url + "\n")

    return results


