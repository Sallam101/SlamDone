from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

class SlamDoneV712CompileContractTest(unittest.TestCase):
    def test_timer_theme_wrapper_keeps_named_child_expression_open(self):
        src = (ROOT / 'lib/src/widgets/floating_timer_overlay.dart').read_text(encoding='utf-8')
        start = src.index('    return Theme(')
        end = src.index('\n  Widget _resizeHandle', start)
        block = src[start:end]
        self.assertNotIn('\n    );\n    );\n', block, 'AnimatedOpacity child must close with a comma before Theme closes')
        self.assertRegex(block, re.compile(r'\n\s*\),\n\s*\),\n\s*\),\n\s*\);\n\s*\}\s*$', re.S))

if __name__ == '__main__':
    unittest.main()
