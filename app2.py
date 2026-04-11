import streamlit as st

st.title("💼 Skill-Based Role Recommender")

st.write("Select your skills to find your suitable role")

# Input
name = st.text_input("Enter your name")

skills = st.multiselect(
    "Select your skills",
    [
        "Python", "SQL", "Power BI",
        "EDA", "Statistics",
        "Machine Learning",
        "Deep Learning",
        "Gen AI"
    ]
)

# Button
if st.button("Suggest Role"):

    if not name:
        st.error("Please enter your name")

    elif not skills:
        st.warning("Please select at least one skill")

    else:
        st.success(f"Hello {name}! Based on your skills 👇")

        skills_set = set(skills)

        # Basic roles
        if skills_set == {"Python"}:
            st.write("Role: Python Developer")

        elif skills_set == {"SQL"}:
            st.write("Role: SQL Developer")

        elif skills_set == {"Power BI"}:
            st.write("Role: Power BI Developer")

        # Data Analyst
        elif {"Python", "SQL", "Power BI", "EDA", "Statistics"}.issubset(skills_set):

            if "Machine Learning" in skills_set:

                if "Deep Learning" in skills_set:

                    if "Gen AI" in skills_set:
                        st.write("Role: AI Developer 🚀")
                    else:
                        st.write("Role: Data Scientist")

                else:
                    st.write("Role: ML Engineer")

            else:
                st.write("Role: Data Analyst")

        else:
            st.write("You are exploring! Keep building your skills 🚀")