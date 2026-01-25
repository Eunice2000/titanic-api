from __future__ import annotations

from marshmallow import fields, Schema
from sqlalchemy.dialects.postgresql import UUID
from . import db
import uuid

class Person(db.Model):
    """
    Database model for storing the data of people on the Titanic
    """
    __tablename__ = 'people'

    uuid = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    survived = db.Column(db.Integer)
    passengerClass = db.Column(db.Integer)
    name = db.Column(db.String(255))
    sex = db.Column(db.String(6))
    age = db.Column(db.Float)
    siblingsOrSpousesAboard = db.Column(db.Integer)
    parentsOrChildrenAboard = db.Column(db.Integer)
    fare = db.Column(db.Float)

    def __init__(self, data):
        self.survived = data.get('survived')
        self.passengerClass = data.get('passengerClass')
        self.name = data.get('name')
        self.sex = data.get('sex')
        self.age = data.get('age')
        self.siblingsOrSpousesAboard = data.get('siblingsOrSpousesAboard')
        self.parentsOrChildrenAboard = data.get('parentsOrChildrenAboard')
        self.fare = data.get('fare')

    def save(self) -> None:
        """
        Save new person to the database
        """
        db.session.add(self)
        db.session.commit()

    def update(self, data: dict) -> None:
        """
        Update an existing person in the database

        Parameters:
            data: dict containing attributes to be updated, missing attributes will stay unaltered
        """
        for key, item in data.items():
            setattr(self, key, item)
        db.session.commit()

    def delete(self) -> None:
        """
        Delete a person from the database
        """
        db.session.delete(self)
        db.session.commit()

    @staticmethod
    def get_all() -> list:
        """
        Get all people from the database

        Returns:
            A list of all people in the database
        """
        return Person.query.all()

    @staticmethod
    def get_by_id(person_uuid: str) -> Person:
        """
        Gets a person by UUID from the database

        Parameters:
            person_uuid: the UUID of the person to retrieve

        Returns:
            The person matching the UUID as a Person instance
        """
        return Person.query.get(person_uuid)

    def __str__(self) -> str:
        """
        Creates and returns a human-readable stringified representation of the object.

        Returns:
            The stringified representation
        """
        return self.name


class PersonSchema(Schema):
    """
    Schema of the table representing a person in the database
    """
    uuid = fields.UUID(required=True)
    survived = fields.Int(required=True)
    passengerClass = fields.Int(required=True)
    name = fields.String(required=True)
    sex = fields.String(required=True)
    age = fields.Int(required=True)
    siblingsOrSpousesAboard = fields.Int(required=True)
    parentsOrChildrenAboard = fields.Int(required=True)
    fare = fields.Float(required=True)
