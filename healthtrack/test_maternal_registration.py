import requests
import json

# Test maternal care registration with different civil statuses
def test_maternal_registration():
    base_url = "http://10.243.17.91:3000"
    
    # Test data for Single status (should not require pregnancy info)
    single_user_data = {
        "username": "single_mother_test",
        "password": "password123",
        "email": "single@test.com",
        "serviceType": "maternal",
        "motherName": "Single Mother",
        "dob": "1990-01-01",
        "education": "College",
        "occupation": "Teacher",
        "status": "Single",  # Single status - should not require pregnancy info
        "religion": "Christian",
        "address": "Test Address",
        "contact": "1234567890",
        "age": "30",
        "sex": "Female",  # Add the required sex field
        # Empty values for spouse fields (should be acceptable for Single status)
        "spouseName": "",
        "spouseDob": "",
        "spouseEducation": "",
        "spouseOccupation": "",
        "monthlyIncome": "0",
        "livingChildrenCount": "0",
        "birthPlan": "",
        "birthAttendant": "",
        "facilityType": "",
        "recordType": "Maternal Care",
        "recordDescription": "Test maternal care record for single mother"
    }
    
    # Test data for Married status (should require pregnancy info)
    married_user_data = {
        "username": "married_mother_test",
        "password": "password123",
        "email": "married@test.com",
        "serviceType": "maternal",
        "motherName": "Married Mother",
        "dob": "1985-05-15",
        "education": "High School",
        "occupation": "Nurse",
        "status": "Married",  # Married status - should require pregnancy info
        "religion": "Catholic",
        "address": "Married Address",
        "contact": "0987654321",
        "age": "35",
        "sex": "Female",
        # Pregnancy info required for Married status
        "spouseName": "Spouse Name",
        "spouseDob": "1983-03-10",
        "spouseEducation": "Bachelor",
        "spouseOccupation": "Engineer",
        "monthlyIncome": "50000",
        "livingChildrenCount": "2",
        "birthPlan": "Hospital",
        "birthAttendant": "SBA",
        "facilityType": "Hospital",
        "recordType": "Maternal Care",
        "recordDescription": "Test maternal care record for married mother"
    }
    
    try:
        print("Testing maternal registration for Single status...")
        response = requests.post(f"{base_url}/api/auth/register", json=single_user_data)
        print(f"Single status registration result: {response.status_code}")
        print(f"Response: {response.json()}")
        
        print("\nTesting maternal registration for Married status...")
        response = requests.post(f"{base_url}/api/auth/register", json=married_user_data)
        print(f"Married status registration result: {response.status_code}")
        print(f"Response: {response.json()}")
        
        print("\n✅ All tests completed!")
    except Exception as e:
        print(f"❌ Test failed: {e}")

if __name__ == "__main__":
    test_maternal_registration()