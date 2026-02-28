
import re
import unicodedata

def to_pascal_case(name):
    """Converts snake_case or kebab-case to PascalCase."""
    # Handle potential separators and capitalize parts
    parts = re.split(r'[-_]', name)
    return "".join(part[0].upper() + part[1:] if part else "" for part in parts)

def to_snake_case(name):
    """Converts PascalCase or camelCase to snake_case."""
    # Insert underscore before uppercase letters (except the first one)
    s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
    # Insert underscore before uppercase letters that follow lowercase letters or digits
    s2 = re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1)
    # Convert to lowercase and handle existing separators
    result = s2.lower()
    # Replace any existing hyphens with underscores
    result = result.replace('-', '_')
    # Clean up multiple underscores
    result = re.sub('_+', '_', result)
    # Remove leading/trailing underscores
    return result.strip('_')

def to_slug(name: str) -> str:
    # só deixa letras, números, ponto, underscore, hífen e dois-pontos (seguros p/ QName)
    return re.sub(r'[^A-Za-z0-9._-]', '_', str(name.replace(':', '_')))

def to_camel_case(name: str) -> str:
    """Converts snake_case or kebab-case to camelCase."""
    # Handle potential separators and capitalize parts
    parts = re.split(r'[-_]', name)
    return parts[0] + "".join(part.capitalize() for part in parts[1:])

def to_kebab_case(name: str) -> str:
    """Converts snake_case or camelCase to kebab-case."""
    # Insert hyphen before uppercase letters (except the first one)
    s1 = re.sub('(.)([A-Z][a-z]+)', r'\1-\2', name)
    # Insert hyphen before uppercase letters that follow lowercase letters or digits
    s2 = re.sub('([a-z0-9])([A-Z])', r'\1-\2', s1)
    # Convert to lowercase and handle existing separators
    result = s2.lower()
    # Replace any existing underscores with hyphens
    result = result.replace('_', '-')
    # Clean up multiple hyphens
    result = re.sub('-+', '-', result)
    # Remove leading/trailing hyphens
    return result.strip('-')

def sanitize_text(s: str) -> str:
    # remove todos os caracteres de formatação (categoria Cf, ex.: U+202A, U+202C)
    s = ''.join(ch for ch in s if unicodedata.category(ch) != 'Cf')
    # normaliza espaço não quebrável para espaço ASCII
    s = s.replace('\xa0', ' ')
    # normaliza hífens comuns para ASCII '-'
    s = s.replace('\u2011', '-')  # non-breaking hyphen
    s = s.replace('\u2010', '-')  # hyphen
    s = s.replace('\u2013', '-')  # en dash
    s = s.replace('\u2014', '-')  # em dash
    s = s.replace('\u2212', '-')  # minus sign
    # opcional: NFKC para compatibilidade
    s = unicodedata.normalize('NFKC', s)

    return s

def slugify_text(label: str) -> str:
    # normalize to snake-case: lower, replace non-alphanumerics with underscore, trim edges
    return re.sub(r'[^a-z0-9]+', '_', label.lower()).strip('_')

def remove_special_chars(s: str) -> str:
    s = sanitize_text(s.strip().lstrip("~"))
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(ch for ch in s if not unicodedata.combining(ch))
    s = s.replace(' ', '_')
    s = re.sub(r'[^A-Za-z0-9_]', '', s)

    return s.replace('(', '').replace(')', '').lower()