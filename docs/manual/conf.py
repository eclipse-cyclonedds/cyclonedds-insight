from pathlib import Path
from datetime import datetime
import subprocess
import json
import sys

# -- Project information -----------------------------------------------------

variables = json.loads((Path(__file__).parent / "variables.json").read_text())
variables["copyright"] = variables["copyright"].replace(':year:', str(datetime.now().year))

project = variables["project"]
copyright = variables["copyright"].replace(':year:', '')
author = variables['author']

version = variables['version']
release = variables['release']

# -- General configuration ---------------------------------------------------

extensions = [
    'breathe',
    'sphinx.ext.intersphinx',
    "sphinx.ext.viewcode",
    "sphinx.ext.autosummary",
    "sphinx.ext.extlinks",
    "sphinx.ext.todo",
    "sphinx_tabs.tabs"
]

templates_path = ['_templates']
language = 'en'
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store','**/*.part.rst']
needs_sphinx = '4.0'

# -- Options for HTML output -------------------------------------------------

try:
    import piccolo_theme
    extensions.append('piccolo_theme')
    html_theme = 'piccolo_theme'
    html_css_files = ['css/helpers.css']
    html_js_files = ['js/helpers.js']
except ImportError:
    import warnings
    warnings.warn("piccolo_theme is not installed. Falling back to alabaster.")
    html_theme = 'alabaster'


html_static_path = ['_static']
html_title = f"{project}, {version}"
html_short_title = html_title

autosummary_generate = True

# -- Export variables to be used in RST --------------------------------------

rst_epilog = '\n'.join(map(lambda x: f".. |var-{x[0]}| replace:: {x[1]}", variables.items()))
