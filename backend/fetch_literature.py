import os
import requests
import time

fields = [
    "Addiction", "Allergy & Immunology", "Anesthesia", "Biochemistry", "Cardiology",
    "Dentistry", "Dermatology", "Diabetes", "Embryology", "Emergency & Critical Care",
    "Endocrinology", "Anatomy", "HIV/AIDS", "Ophthalmology", "Forensic Medicine",
    "Internal Medicine", "Epidemiology", "Family Medicine", "General Medicine",
    "Genetics", "Gastroenterology", "Gynecology", "Hematology", "Histology",
    "Infectious Diseases", "Microbiology", "Physiology", "Military Medicine",
    "Pulmonology", "Veterinary Medicine", "NeuroAnatomy", "NeuroImaging",
    "Neurology", "NeuroPathology", "NeuroSurgery", "Nutrition", "Oncology",
    "Orthopedics", "Otorhinolaryngology", "Pediatrics", "Pathology", "Neonatology",
    "Hepatology", "ENT", "Evidence Based Medicine", "Pharmacology", "Psychiatry",
    "Radiology", "Respiratory Diseases", "Rheumatology", "Surgery", "Toxicology",
    "Traumatology", "Urology", "Psychology", "Nursing", "Homeopathy", "Neuroradiology",
    "Surgical Anatomy"
]

os.makedirs("data/literature", exist_ok=True)

def fetch_pdf_for_field(field):
    # Query Europe PMC for open access review articles
    query = f'({field}) AND (SRC:MED AND OPEN_ACCESS:Y)'
    url = f'https://www.ebi.ac.uk/europepmc/webservices/rest/search?query={query}&format=json&resultType=core&pageSize=1'
    
    try:
        res = requests.get(url, timeout=10)
        data = res.json()
        results = data.get("resultList", {}).get("result", [])
        
        if not results:
            print(f"No results found for {field}")
            return
            
        pmcid = results[0].get("pmcid")
        if not pmcid:
            print(f"No PMCID found for {field}")
            return
            
        # Download the PDF via Europe PMC direct link (more reliable than NCBI for bots)
        pdf_url = f'https://europepmc.org/articles/{pmcid}?pdf=render'
        headers = {'User-Agent': 'Mozilla/5.0'}
        pdf_res = requests.get(pdf_url, headers=headers, timeout=30)
        
        if pdf_res.status_code == 200 and b'%PDF' in pdf_res.content[:10]:
            safe_name = field.replace("/", "_").replace(" ", "_").replace("&", "and")
            filepath = os.path.join("data/literature", f"{safe_name}.pdf")
            with open(filepath, "wb") as f:
                f.write(pdf_res.content)
            print(f"Downloaded PDF for {field} -> {filepath}")
        else:
            print(f"Failed to download PDF for {field}, status: {pdf_res.status_code}")
            
    except Exception as e:
        print(f"Error fetching {field}: {e}")

if __name__ == "__main__":
    print(f"Starting download for {len(fields)} fields...")
    for field in fields:
        fetch_pdf_for_field(field)
        time.sleep(1)  # Be nice to the API
    print("Done downloading literature.")
