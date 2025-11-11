#!/usr/bin/env python3

###############################################################################
# inbash :: mac/add-photo-to-pdf.py
# ---------------------------------------------------------------------------
# Description : A comprehensive CLI tool to insert images into PDF files at
#               specific positions with various positioning options and image
#               size controls. Optimized for adding ID photos to A4 forms.
# Usage       : ./add-photo-to-pdf.py <pdf> <image> <output> [options]
# Example     : ./add-photo-to-pdf.py form.pdf photo.jpg output.pdf --position top-right
# Requirements: Python 3.6+, PyMuPDF (pip install pymupdf)
#
# Installation:
#   1. Create virtual environment:
#      python3 -m venv .venv
#   2. Activate virtual environment:
#      source .venv/bin/activate  # On macOS/Linux
#      .venv\Scripts\activate     # On Windows
#   3. Install dependencies:
#      pip install pymupdf
#   Or use the built-in setup command:
#      ./add-photo-to-pdf.py --setup
###############################################################################

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import Tuple, Optional

try:
    import fitz  # pip install pymupdf
except ImportError:
    fitz = None  # Will be handled later


def setup_environment():
    """Set up virtual environment and install dependencies."""
    script_dir = Path(__file__).parent
    venv_dir = script_dir / '.venv'

    print("="*70)
    print("Setting up virtual environment and dependencies...")
    print("="*70)

    create_venv = False

    # Check if virtual environment already exists
    if venv_dir.exists():
        print(f"\nVirtual environment already exists at: {venv_dir}")
        response = input("Do you want to recreate it? (y/N): ").strip().lower()
        if response != 'y':
            print("Skipping virtual environment creation.")
            create_venv = False
        else:
            import shutil
            print(f"Removing existing virtual environment...")
            shutil.rmtree(venv_dir)
            create_venv = True
    else:
        create_venv = True

    # Create virtual environment
    if create_venv:
        print(f"\n[1/3] Creating virtual environment at: {venv_dir}")
        try:
            subprocess.run(
                [sys.executable, '-m', 'venv', str(venv_dir)],
                check=True
            )
            print("✓ Virtual environment created successfully")
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to create virtual environment: {e}")
            return False

    # Determine pip path
    if sys.platform == 'win32':
        pip_path = venv_dir / 'Scripts' / 'pip.exe'
        python_path = venv_dir / 'Scripts' / 'python.exe'
    else:
        pip_path = venv_dir / 'bin' / 'pip'
        python_path = venv_dir / 'bin' / 'python'

    # Upgrade pip
    print(f"\n[2/3] Upgrading pip...")
    try:
        subprocess.run(
            [str(python_path), '-m', 'pip', 'install', '--upgrade', 'pip'],
            check=True,
            capture_output=True
        )
        print("✓ pip upgraded successfully")
    except subprocess.CalledProcessError as e:
        print(f"✗ Failed to upgrade pip: {e}")
        # Continue anyway

    # Install dependencies
    print(f"\n[3/3] Installing dependencies (PyMuPDF)...")
    requirements_file = script_dir / 'requirements-add-photo-to-pdf.txt'

    try:
        # Try to install from requirements file first
        if requirements_file.exists():
            subprocess.run(
                [str(pip_path), 'install', '-r', str(requirements_file)],
                check=True
            )
        else:
            # Fallback to direct installation
            subprocess.run(
                [str(pip_path), 'install', 'pymupdf'],
                check=True
            )
        print("✓ Dependencies installed successfully")
    except subprocess.CalledProcessError as e:
        print(f"✗ Failed to install dependencies: {e}")
        return False

    # Print activation instructions
    print("\n" + "="*70)
    print("Setup completed successfully!")
    print("="*70)
    print("\nTo use this tool, activate the virtual environment first:")
    if sys.platform == 'win32':
        print(f"  .venv\\Scripts\\activate")
    else:
        print(f"  source .venv/bin/activate")
    print("\nThen run the script:")
    print(f"  python {Path(__file__).name} input.pdf image.jpg output.pdf")
    print("\nOr run directly with the virtual environment python:")
    print(f"  {python_path} {Path(__file__).name} input.pdf image.jpg output.pdf")
    print("="*70)

    return True


class PDFImageInserter:
    """Handle PDF image insertion operations."""

    POSITIONS = {
        'top-left': (True, True),
        'top-right': (False, True),
        'bottom-left': (True, False),
        'bottom-right': (False, False),
        'center': (None, None)
    }

    # Default size: Standard ID/passport photo dimensions
    # 35mm x 45mm = ~99 x 127 points (1mm ≈ 2.83 points)
    DEFAULT_WIDTH = 99
    DEFAULT_HEIGHT = 127

    def __init__(self, pdf_path: str, image_path: str, output_path: str):
        """Initialize the PDF image inserter.

        Args:
            pdf_path: Path to input PDF file
            image_path: Path to image file to insert
            output_path: Path to output PDF file
        """
        self.pdf_path = Path(pdf_path)
        self.image_path = Path(image_path)
        self.output_path = Path(output_path)
        self.pdf = None

    def validate_files(self) -> bool:
        """Validate that input files exist and are accessible.

        Returns:
            True if validation passes, False otherwise
        """
        if not self.pdf_path.exists():
            print(f"Error: PDF file not found: {self.pdf_path}")
            return False

        if not self.image_path.exists():
            print(f"Error: Image file not found: {self.image_path}")
            return False

        # Check if output directory exists
        output_dir = self.output_path.parent
        if not output_dir.exists():
            print(f"Error: Output directory does not exist: {output_dir}")
            return False

        return True

    def calculate_position(
        self,
        page_width: float,
        page_height: float,
        img_width: float,
        img_height: float,
        position: Optional[str] = None,
        x: Optional[float] = None,
        y: Optional[float] = None,
        margin: float = 20
    ) -> Tuple[float, float]:
        """Calculate image position on the page.

        Args:
            page_width: Width of the PDF page
            page_height: Height of the PDF page
            img_width: Width of the image
            img_height: Height of the image
            position: Named position (top-left, top-right, etc.)
            x: X coordinate (if using custom position)
            y: Y coordinate (if using custom position)
            margin: Margin from edges for named positions

        Returns:
            Tuple of (x, y) coordinates for top-left corner of image
        """
        # If custom coordinates provided, use them
        if x is not None and y is not None:
            return (x, y)

        # Use named position
        if position in self.POSITIONS:
            is_left, is_top = self.POSITIONS[position]

            if position == 'center':
                x = (page_width - img_width) / 2
                y = (page_height - img_height) / 2
            else:
                # Calculate X position
                if is_left:
                    x = margin
                else:
                    x = page_width - img_width - margin

                # Calculate Y position (PDF uses bottom-left origin)
                if is_top:
                    y = page_height - img_height - margin
                else:
                    y = margin

            return (x, y)

        # Default to top-right if no position specified
        return (page_width - img_width - margin, page_height - img_height - margin)

    def calculate_image_size(
        self,
        width: Optional[float] = None,
        height: Optional[float] = None,
        scale: Optional[float] = None,
        keep_aspect: bool = True,
        fit_mode: str = 'fit'
    ) -> Tuple[float, float]:
        """Calculate image size based on parameters.

        Args:
            width: Desired width in points
            height: Desired height in points
            scale: Scale factor (0.0-1.0 for percentage of page)
            keep_aspect: Whether to maintain aspect ratio
            fit_mode: How to fit image into target dimensions:
                - 'fit': Scale to fit within bounds, maintaining aspect ratio
                - 'fill': Scale to fill bounds completely, maintaining aspect ratio (may crop)
                - 'stretch': Stretch to exact dimensions, ignoring aspect ratio

        Returns:
            Tuple of (width, height) for the image
        """
        # Load image to get original dimensions
        img = fitz.Pixmap(str(self.image_path))
        original_width = img.width
        original_height = img.height
        aspect_ratio = original_width / original_height

        # If scale provided, use it relative to original size
        if scale is not None:
            return (original_width * scale, original_height * scale)

        # If both width and height provided
        if width is not None and height is not None:
            if fit_mode == 'stretch':
                # Stretch to exact dimensions, ignore aspect ratio
                return (width, height)
            elif fit_mode == 'fill':
                # Scale to fill bounds completely (may crop)
                # Use the larger scaling factor to fill the entire area
                scale_w = width / original_width
                scale_h = height / original_height
                scale_factor = max(scale_w, scale_h)
                return (original_width * scale_factor, original_height * scale_factor)
            else:  # fit_mode == 'fit' or keep_aspect is True
                # Scale to fit within bounds
                # Use the smaller scaling factor to fit within the area
                scale_w = width / original_width
                scale_h = height / original_height
                scale_factor = min(scale_w, scale_h)
                return (original_width * scale_factor, original_height * scale_factor)

        # If only width provided
        if width is not None:
            if keep_aspect:
                return (width, width / aspect_ratio)
            else:
                return (width, original_height)

        # If only height provided
        if height is not None:
            if keep_aspect:
                return (height * aspect_ratio, height)
            else:
                return (original_width, height)

        # Default size if nothing specified
        # Standard ID/passport photo: 35mm x 45mm
        return (self.DEFAULT_WIDTH, self.DEFAULT_HEIGHT)

    def insert_image(
        self,
        page_num: int = 0,
        position: Optional[str] = None,
        x: Optional[float] = None,
        y: Optional[float] = None,
        width: Optional[float] = None,
        height: Optional[float] = None,
        scale: Optional[float] = None,
        margin: float = 20,
        keep_aspect: bool = True,
        opacity: float = 1.0,
        rotation: int = 0,
        fit_mode: str = 'fit'
    ) -> bool:
        """Insert image into PDF.

        Args:
            page_num: Page number to insert image (0-indexed)
            position: Named position (top-left, top-right, etc.)
            x: X coordinate for custom position
            y: Y coordinate for custom position
            width: Image width in points
            height: Image height in points
            scale: Scale factor for image
            margin: Margin from edges for named positions
            keep_aspect: Whether to maintain aspect ratio
            opacity: Image opacity (0.0-1.0)
            rotation: Rotation angle in degrees
            fit_mode: How to fit image into target dimensions

        Returns:
            True if successful, False otherwise
        """
        try:
            # Open PDF
            self.pdf = fitz.open(str(self.pdf_path))

            # Validate page number
            if page_num < 0 or page_num >= len(self.pdf):
                print(f"Error: Page number {page_num} is out of range (PDF has {len(self.pdf)} pages)")
                return False

            page = self.pdf[page_num]
            page_width, page_height = page.rect.width, page.rect.height

            # Calculate image size
            img_width, img_height = self.calculate_image_size(
                width=width,
                height=height,
                scale=scale,
                keep_aspect=keep_aspect,
                fit_mode=fit_mode
            )

            # Calculate position
            x_pos, y_pos = self.calculate_position(
                page_width=page_width,
                page_height=page_height,
                img_width=img_width,
                img_height=img_height,
                position=position,
                x=x,
                y=y,
                margin=margin
            )

            # Create rectangle for image placement
            rect = fitz.Rect(x_pos, y_pos, x_pos + img_width, y_pos + img_height)

            # Insert image with optional parameters
            # Note: opacity parameter requires PyMuPDF >= 1.18.0
            insert_params = {
                'rect': rect,
                'filename': str(self.image_path),
                'rotate': rotation
            }

            # Only add opacity if it's not the default value and the method supports it
            if opacity != 1.0:
                try:
                    page.insert_image(**insert_params, opacity=opacity)
                except TypeError:
                    # Fallback for older PyMuPDF versions that don't support opacity
                    print(f"Warning: PyMuPDF version doesn't support opacity. Using default opacity (1.0)")
                    page.insert_image(**insert_params)
            else:
                page.insert_image(**insert_params)

            # Save output
            self.pdf.save(str(self.output_path))
            print(f"Success! Image inserted into {self.output_path}")
            print(f"  Position: ({x_pos:.2f}, {y_pos:.2f})")
            print(f"  Size: {img_width:.2f} x {img_height:.2f} points")

            return True

        except Exception as e:
            print(f"Error inserting image: {e}")
            return False

        finally:
            if self.pdf:
                self.pdf.close()


def main():
    """Main entry point for CLI."""
    # Handle --setup flag early
    if '--setup' in sys.argv:
        success = setup_environment()
        sys.exit(0 if success else 1)

    # Check if PyMuPDF is available
    if fitz is None:
        print("Error: PyMuPDF is not installed.")
        print("\nTo install dependencies, run:")
        print(f"  {sys.argv[0]} --setup")
        print("\nOr install manually:")
        print("  python3 -m venv .venv")
        print("  source .venv/bin/activate")
        print("  pip install pymupdf")
        sys.exit(1)

    parser = argparse.ArgumentParser(
        description='Insert an image into a PDF file at a specific position.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Setup: Install dependencies in virtual environment
  %(prog)s --setup

  # Insert ID photo at top-right corner with default size (35mm x 45mm / 99 x 127 points)
  %(prog)s application_form.pdf id_photo.jpg completed_form.pdf

  # Insert at specific position
  %(prog)s input.pdf photo.jpg output.pdf --position center
  %(prog)s input.pdf photo.jpg output.pdf --position bottom-left

  # Insert at custom coordinates
  %(prog)s input.pdf photo.jpg output.pdf --x 100 --y 200

  # Specify image size
  %(prog)s input.pdf photo.jpg output.pdf --width 150 --height 200
  %(prog)s input.pdf photo.jpg output.pdf --scale 0.5

  # Fit image to a specific area (e.g., form field, signature box)
  # Fit mode scales image to fit within bounds, maintaining aspect ratio
  %(prog)s input.pdf photo.jpg output.pdf --width 200 --height 100 --fit-mode fit

  # Fill mode scales to fill entire area, may crop to maintain aspect ratio
  %(prog)s input.pdf photo.jpg output.pdf --width 200 --height 100 --fit-mode fill

  # Stretch mode stretches to exact dimensions, ignoring aspect ratio
  %(prog)s input.pdf photo.jpg output.pdf --width 200 --height 100 --fit-mode stretch

  # Insert on specific page with margin
  %(prog)s input.pdf photo.jpg output.pdf --page 2 --margin 30

  # Insert with rotation and opacity
  %(prog)s input.pdf photo.jpg output.pdf --rotation 90 --opacity 0.7

  # Complete example: fit photo to signature box at bottom-right
  %(prog)s document.pdf signature.png signed.pdf --position bottom-right \\
    --width 180 --height 60 --fit-mode fit --margin 40
        '''
    )

    # Setup flag
    parser.add_argument(
        '--setup',
        action='store_true',
        help='Set up virtual environment and install dependencies'
    )

    # Required arguments (optional when using --setup)
    parser.add_argument('pdf', nargs='?', help='Input PDF file')
    parser.add_argument('image', nargs='?', help='Image file to insert (JPG, PNG, etc.)')
    parser.add_argument('output', nargs='?', help='Output PDF file')

    # Page selection
    parser.add_argument(
        '--page', '-p',
        type=int,
        default=0,
        help='Page number to insert image (0-indexed, default: 0)'
    )

    # Position arguments
    position_group = parser.add_mutually_exclusive_group()
    position_group.add_argument(
        '--position',
        choices=['top-left', 'top-right', 'bottom-left', 'bottom-right', 'center'],
        default='top-right',
        help='Named position for image placement (default: top-right)'
    )

    # Custom coordinates
    parser.add_argument(
        '--x',
        type=float,
        help='X coordinate for custom position (points from left edge)'
    )
    parser.add_argument(
        '--y',
        type=float,
        help='Y coordinate for custom position (points from bottom edge)'
    )

    # Size arguments
    size_group = parser.add_mutually_exclusive_group()
    parser.add_argument(
        '--width',
        type=float,
        help='Image width in points (default: 99 points / 35mm for standard ID photo)'
    )
    parser.add_argument(
        '--height',
        type=float,
        help='Image height in points (default: 127 points / 45mm for standard ID photo)'
    )
    size_group.add_argument(
        '--scale',
        type=float,
        help='Scale factor for image (e.g., 0.5 for 50%% of original size)'
    )

    # Additional options
    parser.add_argument(
        '--margin',
        type=float,
        default=20,
        help='Margin from edges for named positions (default: 20 points)'
    )
    parser.add_argument(
        '--fit-mode',
        choices=['fit', 'fill', 'stretch'],
        default='fit',
        help='How to resize image when both width and height are specified:\n'
             '  fit: Scale to fit within bounds, maintaining aspect ratio (default)\n'
             '  fill: Scale to fill bounds completely, may crop to maintain aspect ratio\n'
             '  stretch: Stretch to exact dimensions, ignoring aspect ratio'
    )
    parser.add_argument(
        '--no-aspect',
        action='store_true',
        help='Do not maintain aspect ratio when resizing (deprecated: use --fit-mode stretch)'
    )
    parser.add_argument(
        '--opacity',
        type=float,
        default=1.0,
        help='Image opacity (0.0-1.0, default: 1.0)'
    )
    parser.add_argument(
        '--rotation',
        type=int,
        default=0,
        choices=[0, 90, 180, 270],
        help='Rotation angle in degrees (default: 0)'
    )

    args = parser.parse_args()

    # Validate required arguments
    if not args.pdf or not args.image or not args.output:
        parser.print_help()
        print("\nError: PDF, image, and output file paths are required")
        sys.exit(1)

    # Validate opacity
    if not 0.0 <= args.opacity <= 1.0:
        print("Error: Opacity must be between 0.0 and 1.0")
        sys.exit(1)

    # Validate coordinates usage
    if (args.x is not None or args.y is not None):
        if args.x is None or args.y is None:
            print("Error: Both --x and --y must be specified for custom coordinates")
            sys.exit(1)
        # If custom coordinates provided, ignore position argument
        position = None
    else:
        position = args.position

    # Handle --no-aspect flag (deprecated, but maintain backwards compatibility)
    fit_mode = args.fit_mode
    if args.no_aspect and fit_mode == 'fit':
        fit_mode = 'stretch'

    # Create inserter and process
    inserter = PDFImageInserter(args.pdf, args.image, args.output)

    # Validate files
    if not inserter.validate_files():
        sys.exit(1)

    # Insert image
    success = inserter.insert_image(
        page_num=args.page,
        position=position,
        x=args.x,
        y=args.y,
        width=args.width,
        height=args.height,
        scale=args.scale,
        margin=args.margin,
        keep_aspect=not args.no_aspect,
        opacity=args.opacity,
        rotation=args.rotation,
        fit_mode=fit_mode
    )

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
