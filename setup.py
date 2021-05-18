import setuptools

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setuptools.setup(
    name="n2o_inv",
    version="0.0.1",
    author="Angharad Stell",
    author_email="a.stell@bristol.ac.uk",
    description="Global N2O inversion",
    long_description=long_description,
    long_description_content_type="text/markdown",
    packages=setuptools.find_packages(),
    python_requires=">=3.6",
)