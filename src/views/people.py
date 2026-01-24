from flask import request, json, Response, Blueprint
from ..models.person import Person, PersonSchema


people_api = Blueprint('people', __name__)
person_schema = PersonSchema()


@people_api.route('people', methods=['GET'])
def get_all() -> Response:
    """
    Endpoint returning all people from the database

    Returns:
        Response containing all people
    """
    people = Person.get_all()
    people_serialized = person_schema.dump(people, many=True)

    return custom_response(people_serialized, 200)

@people_api.route('people/<person_uuid>', methods=['PUT'])
def update_person(person_uuid: str) -> Response:
    """
    Endpoint to update a person

    Parameters:
        person_uuid: the UUID of the person

    Returns:
        Response containing the updated person
    """
    person = Person.get_by_id(person_uuid)
    if isinstance(person, type(None)):
        return custom_response("Person not found", 404)
    request_data = request.get_json()
    person.update(request_data)
    people_serialized = person_schema.dump(person)

    return custom_response(people_serialized, 200)

@people_api.route('people/<person_uuid>', methods=['DELETE'])
def delete_person(person_uuid: str) -> Response:
    """
    Endpoint to delete a person

    Parameters:
        person_uuid: the UUID of the person

    Returns:
        OK or 404.
    """
    person = Person.get_by_id(person_uuid)
    if isinstance(person, type(None)):
        return custom_response("Person not found", 404)
    person.delete()
    return custom_response("OK", 200)

@people_api.route('people/<person_uuid>', methods=['GET'])
def get_by_id(person_uuid: str) -> Response:
    """
    Endpoint returning a person by their UUID from the database

    Parameters:
        person_uuid: the UUID of the person

    Returns:
        Response containing the selected person
    """
    people = Person.get_by_id(person_uuid)
    if isinstance(people, type(None)):
        return custom_response("Person not found",404)
    people_serialized = person_schema.dump(people)

    return custom_response(people_serialized, 200)


@people_api.route('people', methods=['POST'])
def add_passenger() -> Response:
    """
    Endpoint adding a new person to the database based on the JSON payload of the request

    Returns:
        Response containing the added person
    """
    request_data = request.get_json()
    data = person_schema.load(request_data, partial=True)

    new_passenger = Person(data)
    new_passenger.save()

    serialized_data = person_schema.dump(new_passenger)

    return custom_response(serialized_data, 200)


def custom_response(response_body: dict, status_code: int) -> Response:
    """
    Wrapper function creating a response with common parameters
    
    Parameters:
        response_body: the response body
        status_code: the status code of the response
        
    Returns:
        The Response object that Flask can return  
    """
    return Response(
        mimetype="application/json",
        response=json.dumps(response_body),
        status=status_code
    )
