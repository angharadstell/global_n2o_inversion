from unittest.mock import patch

import pytest

# this is automatically applied to every pytest function
# and stops matplotlib output from being shown. 
# yield means the patch is no longer applied once the 
# pytest function has run. This means if you turn off the 
# autouse for one function, then this patch will not be 
# still running form the last function. 
@pytest.fixture(autouse=True)
def no_show():
    with patch("matplotlib.pyplot.show"):
        yield
