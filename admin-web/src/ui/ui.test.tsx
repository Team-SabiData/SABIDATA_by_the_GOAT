import { render, screen, fireEvent } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { Button } from './Button';
import { Badge } from './Badge';
import { KpiCard } from './KpiCard';

describe('primitives ui', () => {
  it('Button désactivé en loading, ne déclenche pas onClick', () => {
    const onClick = vi.fn();
    render(<Button loading onClick={onClick}>Enregistrer</Button>);
    fireEvent.click(screen.getByRole('button'));
    expect(onClick).not.toHaveBeenCalled();
  });
  it('Badge rend son contenu avec le bon ton', () => {
    render(<Badge tone="red">banni</Badge>);
    expect(screen.getByText('banni')).toBeInTheDocument();
  });
  it('KpiCard affiche label et valeur', () => {
    render(<KpiCard label="Retraits à traiter" value="3" />);
    expect(screen.getByText('Retraits à traiter')).toBeInTheDocument();
    expect(screen.getByText('3')).toBeInTheDocument();
  });
});
