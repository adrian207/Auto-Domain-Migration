# Name and organizational data for AD test user generation

# Common first names (100 names)
$script:FirstNames = @(
    "James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
    "William", "Barbara", "David", "Elizabeth", "Richard", "Susan", "Joseph", "Jessica",
    "Thomas", "Sarah", "Charles", "Karen", "Christopher", "Nancy", "Daniel", "Lisa",
    "Matthew", "Betty", "Anthony", "Margaret", "Mark", "Sandra", "Donald", "Ashley",
    "Steven", "Kimberly", "Paul", "Emily", "Andrew", "Donna", "Joshua", "Michelle",
    "Kenneth", "Dorothy", "Kevin", "Carol", "Brian", "Amanda", "George", "Melissa",
    "Edward", "Deborah", "Ronald", "Stephanie", "Timothy", "Rebecca", "Jason", "Sharon",
    "Jeffrey", "Laura", "Ryan", "Cynthia", "Jacob", "Kathleen", "Gary", "Amy",
    "Nicholas", "Shirley", "Eric", "Angela", "Jonathan", "Helen", "Stephen", "Anna",
    "Larry", "Brenda", "Justin", "Pamela", "Scott", "Nicole", "Brandon", "Emma",
    "Benjamin", "Samantha", "Samuel", "Katherine", "Raymond", "Christine", "Gregory", "Debra",
    "Frank", "Rachel", "Alexander", "Catherine", "Patrick", "Carolyn", "Jack", "Janet"
)

# Common last names (100 surnames)
$script:LastNames = @(
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
    "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas",
    "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White",
    "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker", "Young",
    "Allen", "King", "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores",
    "Green", "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell",
    "Carter", "Roberts", "Gomez", "Phillips", "Evans", "Turner", "Diaz", "Parker",
    "Cruz", "Edwards", "Collins", "Reyes", "Stewart", "Morris", "Morales", "Murphy",
    "Cook", "Rogers", "Gutierrez", "Ortiz", "Morgan", "Cooper", "Peterson", "Bailey",
    "Reed", "Kelly", "Howard", "Ramos", "Kim", "Cox", "Ward", "Richardson",
    "Watson", "Brooks", "Chavez", "Wood", "James", "Bennett", "Gray", "Mendoza",
    "Ruiz", "Hughes", "Price", "Alvarez", "Castillo", "Sanders", "Patel", "Myers"
)

# Job titles by department
$script:JobTitles = @{
    "IT" = @(
        "Chief Technology Officer",
        "IT Director",
        "Systems Administrator",
        "Senior Systems Administrator",
        "Network Engineer",
        "Senior Network Engineer",
        "Security Analyst",
        "Senior Security Analyst",
        "Help Desk Manager",
        "Help Desk Technician",
        "Database Administrator",
        "Senior Database Administrator",
        "DevOps Engineer",
        "Cloud Architect",
        "IT Support Specialist"
    )
    "HR" = @(
        "Chief Human Resources Officer",
        "HR Director",
        "HR Manager",
        "Senior HR Manager",
        "Recruiter",
        "Senior Recruiter",
        "HR Coordinator",
        "HR Specialist",
        "Benefits Administrator",
        "Payroll Specialist",
        "Payroll Manager",
        "Training Coordinator",
        "Employee Relations Specialist"
    )
    "Finance" = @(
        "Chief Financial Officer",
        "Finance Director",
        "Controller",
        "Senior Accountant",
        "Accountant",
        "Financial Analyst",
        "Senior Financial Analyst",
        "Accounts Payable Clerk",
        "Accounts Receivable Clerk",
        "Budget Analyst",
        "Tax Specialist",
        "Audit Manager",
        "Treasury Analyst"
    )
    "Engineering" = @(
        "Chief Engineering Officer",
        "VP of Engineering",
        "Engineering Director",
        "Engineering Manager",
        "Principal Engineer",
        "Senior Software Engineer",
        "Software Engineer",
        "Junior Software Engineer",
        "QA Engineer",
        "Senior QA Engineer",
        "DevOps Engineer",
        "Site Reliability Engineer",
        "Product Manager",
        "Senior Product Manager",
        "Technical Lead",
        "Software Architect"
    )
    "Sales" = @(
        "Chief Sales Officer",
        "VP of Sales",
        "Sales Director",
        "Regional Sales Manager",
        "Sales Manager",
        "Senior Account Executive",
        "Account Executive",
        "Sales Representative",
        "Inside Sales Representative",
        "Sales Engineer",
        "Business Development Manager",
        "Business Development Representative",
        "Sales Operations Manager",
        "Sales Coordinator"
    )
    "Marketing" = @(
        "Chief Marketing Officer",
        "VP of Marketing",
        "Marketing Director",
        "Marketing Manager",
        "Product Marketing Manager",
        "Content Manager",
        "Content Writer",
        "Social Media Manager",
        "Digital Marketing Specialist",
        "Marketing Coordinator",
        "Marketing Analyst",
        "Graphic Designer",
        "Senior Graphic Designer",
        "Brand Manager",
        "Communications Manager"
    )
    "Executives" = @(
        "Chief Executive Officer",
        "Chief Operating Officer",
        "Chief Technology Officer",
        "Chief Financial Officer",
        "Chief Human Resources Officer",
        "Chief Marketing Officer",
        "Chief Sales Officer",
        "Chief Engineering Officer",
        "VP of Operations",
        "VP of Strategy"
    )
}

# Office locations
$script:Locations = @{
    "NewYork" = @{
        Code = "NYC"
        Address = "123 Manhattan Ave"
        City = "New York"
        State = "NY"
        ZIP = "10001"
        Phone = "(212) 555-"
        Country = "US"
    }
    "LosAngeles" = @{
        Code = "LAX"
        Address = "456 Hollywood Blvd"
        City = "Los Angeles"
        State = "CA"
        ZIP = "90001"
        Phone = "(323) 555-"
        Country = "US"
    }
    "Chicago" = @{
        Code = "CHI"
        Address = "789 Michigan Ave"
        City = "Chicago"
        State = "IL"
        ZIP = "60601"
        Phone = "(312) 555-"
        Country = "US"
    }
    "London" = @{
        Code = "LON"
        Address = "101 Oxford Street"
        City = "London"
        State = "England"
        ZIP = "SW1A 1AA"
        Phone = "+44 20 7946 "
        Country = "UK"
    }
    "Tokyo" = @{
        Code = "TYO"
        Address = "1-2-3 Shibuya"
        City = "Tokyo"
        State = "Tokyo"
        ZIP = "150-0002"
        Phone = "+81 3 3000 "
        Country = "JP"
    }
    "Sydney" = @{
        Code = "SYD"
        Address = "100 George Street"
        City = "Sydney"
        State = "NSW"
        ZIP = "2000"
        Phone = "+61 2 9000 "
        Country = "AU"
    }
}

# Department codes for computer names
$script:DepartmentCodes = @{
    "IT" = "IT"
    "HR" = "HR"
    "Finance" = "FIN"
    "Engineering" = "ENG"
    "Sales" = "SAL"
    "Marketing" = "MKT"
}

