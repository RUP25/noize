#!/usr/bin/env python3
"""
Script to create an admin user.
Usage: python scripts/create_admin_user.py
"""
import asyncio
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db import AsyncSessionLocal
from app.models import User
from app.password_utils import hash_password
from sqlalchemy import select


async def create_admin_user():
    """Create or update an admin user."""
    async with AsyncSessionLocal() as db:
        try:
            # Get email from user input
            print("=" * 60)
            print("Create Admin User")
            print("=" * 60)
            
            email = input("Enter admin email: ").strip()
            if not email:
                print("❌ Email is required!")
                return
            
            password = input("Enter admin password: ").strip()
            if not password or len(password) < 6:
                print("❌ Password must be at least 6 characters!")
                return
            
            contact = input("Enter phone number (required): ").strip()
            if not contact:
                print("❌ Phone number is required!")
                return
            
            # Check if user already exists by email
            result = await db.execute(select(User).where(User.email == email))
            existing_user_by_email = result.scalars().first()
            
            # Check if user already exists by contact
            result = await db.execute(select(User).where(User.contact == contact))
            existing_user_by_contact = result.scalars().first()
            
            if existing_user_by_email:
                # Update existing user to admin
                print(f"\n✓ User with email '{email}' already exists.")
                
                # Check if contact matches or if contact is already used by another user
                if existing_user_by_email.contact != contact:
                    if existing_user_by_contact and existing_user_by_contact.id != existing_user_by_email.id:
                        print(f"❌ Phone number '{contact}' is already registered to another user!")
                        return
                    # Update contact if different
                    existing_user_by_email.contact = contact
                
                response = input("Make this user an admin? (y/n): ").strip().lower()
                if response != 'y':
                    print("Cancelled.")
                    return
                
                existing_user_by_email.is_admin = True
                existing_user_by_email.password_hash = hash_password(password)
                await db.commit()
                print(f"\n✅ User '{email}' is now an admin!")
            elif existing_user_by_contact:
                # Contact exists but email doesn't - ask user what to do
                print(f"\n⚠️  Phone number '{contact}' is already registered to another user (email: {existing_user_by_contact.email or 'N/A'}).")
                response = input("Make this existing user an admin? (y/n): ").strip().lower()
                if response != 'y':
                    print("Cancelled.")
                    return
                
                # Update existing user
                existing_user_by_contact.email = email
                existing_user_by_contact.is_admin = True
                existing_user_by_contact.password_hash = hash_password(password)
                await db.commit()
                print(f"\n✅ User with phone '{contact}' is now an admin!")
            else:
                # Create new admin user
                password_hash = hash_password(password)
                new_user = User(
                    email=email,
                    contact=contact,
                    password_hash=password_hash,
                    is_admin=True,
                    is_artist=False,
                    user_role='guest'
                )
                db.add(new_user)
                await db.commit()
                await db.refresh(new_user)
                print(f"\n✅ Admin user '{email}' created successfully!")
            
            print("\n" + "=" * 60)
            print("Admin Credentials:")
            print(f"Email: {email}")
            print(f"Password: {password}")
            print("=" * 60)
            print("\nYou can now login to the admin dashboard at http://localhost:3001")
            
        except Exception as e:
            await db.rollback()
            print(f"\n❌ Error: {e}")
            raise


if __name__ == "__main__":
    try:
        asyncio.run(create_admin_user())
    except KeyboardInterrupt:
        print("\n\n⚠️  Cancelled by user")
        sys.exit(1)
    except Exception as e:
        sys.exit(1)
